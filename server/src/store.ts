import { mkdir, open, readFile, rename, unlink, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { BudgetExhaustedError } from './collect.ts';
import { validateSnapshot } from './contract.ts';
import type { Snapshot } from './contract.ts';

export async function atomicJSON(path: string, value: unknown) {
  const temp = `${path}.${crypto.randomUUID()}.tmp`;
  try { await writeFile(temp, JSON.stringify(value, null, 2) + '\n'); await rename(temp, path); }
  finally { await unlink(temp).catch(() => {}); }
}
export async function withLock<T>(directory: string, action: () => Promise<T>): Promise<T> {
  await mkdir(directory, { recursive: true });
  const path = join(directory, '.collect.lock');
  const lock = await open(path, 'wx');
  try { await lock.writeFile(String(process.pid)); return await action(); }
  finally { await lock.close(); await unlink(path); }
}
export async function loadSnapshot(directory: string, name: 'latest.json' | 'checkpoint.json' = 'latest.json'): Promise<Snapshot | undefined> {
  try { return validateSnapshot(JSON.parse(await readFile(join(directory, name), 'utf8'))); }
  catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return undefined;
    throw error;
  }
}
// Caller holds the directory lock. Immutable history plus atomic current document.
export async function publish(directory: string, snapshot: Snapshot, production: boolean) {
  validateSnapshot(snapshot);
  if (production && snapshot.samples.some(s => s.source !== 'kakao-future')) throw Error('Synthetic production data refused');
  if (snapshot.enabled && !snapshot.samples.length) throw Error('Empty enabled snapshot refused');
  await mkdir(join(directory, 'snapshots'), { recursive: true });
  const filename = `${snapshot.snapshotId}.json`;
  if (!/^[a-zA-Z0-9_-]+\.json$/.test(filename)) throw Error('Invalid snapshot id');
  const path = join(directory, 'snapshots', filename);
  const body = JSON.stringify(snapshot, null, 2) + '\n';
  try { await writeFile(path, body, { flag: 'wx' }); }
  catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'EEXIST') throw error;
    // Resume an interrupted publish, but never overwrite history under the same id.
    if (await readFile(path, 'utf8') !== body) throw Error('Snapshot id already contains different data');
  }
  await atomicJSON(join(directory, 'latest.json'), snapshot);
}
export async function reserveBudget(directory: string, month: string, limit: number) {
  const path = join(directory, 'budget.json');
  let budget: Record<string, number> = {};
  try { budget = JSON.parse(await readFile(path, 'utf8')); }
  catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
  if (!budget || typeof budget !== 'object' || Array.isArray(budget)
      || Object.values(budget).some(v => !Number.isInteger(v) || v < 0)) throw Error('Invalid budget ledger');
  if ((budget[month] ?? 0) >= limit) throw new BudgetExhaustedError('Monthly budget exhausted');
  budget[month] = (budget[month] ?? 0) + 1;
  await atomicJSON(path, budget); // Reserve before issuing a potentially billable request.
}
