/** Asset helpers. URLs are relative to the API origin (SPEC §3.4). */

export const STATIC_ASSET_PREFIX = '/static/assets/';

export function assetUrl(file: string): string {
  return `${STATIC_ASSET_PREFIX}${encodeURIComponent(file)}`;
}

export interface AssetDto {
  url: string;
  width: number | null;
  height: number | null;
  alt: string;
  format: string;
}

export interface MediaAssetRow {
  url: string;
  width: number | null;
  height: number | null;
  alt_text: string;
  format: string;
}

export function toAssetDto(row: MediaAssetRow): AssetDto {
  return { url: row.url, width: row.width, height: row.height, alt: row.alt_text, format: row.format };
}

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

/** Reads width/height from a PNG's IHDR chunk; returns null if the buffer is not a PNG. */
export function readPngSize(buffer: Buffer): { width: number; height: number } | null {
  if (buffer.length < 24 || !buffer.subarray(0, 8).equals(PNG_SIGNATURE)) return null;
  if (buffer.toString('ascii', 12, 16) !== 'IHDR') return null;
  return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
}
