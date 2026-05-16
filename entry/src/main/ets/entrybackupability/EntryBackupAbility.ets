// entry/src/main/ets/entrybackupability/EntryBackupAbility.ets
import { BackupExtensionAbility, BundleVersion } from '@kit.AbilityKit';

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup() {
    console.log('Obsidian onBackup');
    return {
      resultCode: 0,
      resultInfo: 'Backup success'
    };
  }

  async onRestore(bundleVersion: BundleVersion) {
    console.log('Obsidian onRestore');
    return {
      resultCode: 0,
      resultInfo: 'Restore success'
    };
  }
}
