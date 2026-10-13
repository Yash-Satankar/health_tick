import { UI_ASSET_COPY_PREFIX } from '../../admin/seed.js';
import { toAssetDto, type AssetDto } from '../../lib/assets.js';
import type { AppConfigRepository } from './app-config.repository.js';

export const DEFAULT_LOCALE = 'en';

export interface BootstrapDto {
  contentVersion: number;
  user: { id: string; displayName: string; healthPointsTotal: number };
  copy: Record<string, string>;
  assets: Record<string, AssetDto>;
  feedbackReasons: { id: string; key: string; label: string; requiresText: boolean }[];
}

const camelCase = (name: string) => name.replace(/_([a-z0-9])/g, (_m, c: string) => c.toUpperCase());

export class AppConfigService {
  constructor(private readonly repo: AppConfigRepository) {}

  async bootstrap(userId: string): Promise<BootstrapDto> {
    const [contentVersion, user, copyRows, reasons] = await Promise.all([
      this.repo.contentVersion(),
      this.repo.user(userId),
      this.repo.copy(DEFAULT_LOCALE),
      this.repo.activeFeedbackReasons(),
    ]);
    const copy: Record<string, string> = {};
    const uiAssets: Record<string, string> = {};
    for (const { key, value } of copyRows) {
      if (key.startsWith(UI_ASSET_COPY_PREFIX))
        uiAssets[camelCase(key.slice(UI_ASSET_COPY_PREFIX.length))] = value;
      else copy[key] = value;
    }
    const assetRows = new Map(
      (await this.repo.assetsByKey(Object.values(uiAssets))).map((row) => [row.key, row]),
    );
    const assets: Record<string, AssetDto> = {};
    for (const [name, key] of Object.entries(uiAssets)) {
      const row = assetRows.get(key);
      if (row) assets[name] = toAssetDto(row);
    }
    return {
      contentVersion,
      user: { id: user.id, displayName: user.display_name, healthPointsTotal: user.health_points_total },
      copy,
      assets,
      feedbackReasons: reasons.map((r) => ({
        id: r.id,
        key: r.key,
        label: r.label,
        requiresText: r.requires_text,
      })),
    };
  }
}
