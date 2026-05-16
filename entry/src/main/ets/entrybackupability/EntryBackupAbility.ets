import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup(): Promise<void> {
    console.log('Obsidian onBackup');
  }

  async onRestore(bundleVersion: BundleVersion): Promise<void> {
    console.log('Obsidian onRestore');
  }
}
