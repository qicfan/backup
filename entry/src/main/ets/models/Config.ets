import { BackupType, ConfigGlobalStatus, DirRule, LowBatteryStop, OnlyWIFIBackup } from "../typing"
import { DB } from "./DB"
import { relationalStore } from "@kit.ArkData";
import { Global } from "./Global";
import { BusinessError } from "@kit.BasicServicesKit";

/**
 * 备份设置
 */
@ObservedV2
export class Config {
  @Trace backupType: BackupType = BackupType.ALL
  @Trace backupRootPath: string = "";
  @Trace dirRule: DirRule = DirRule.YMD;
  @Trace lowBatteryStop: LowBatteryStop = LowBatteryStop.YES;
  @Trace onlyWifi: OnlyWIFIBackup = OnlyWIFIBackup.YES;
  updatedAt: number = 0;
  private db: DB | null = null;

  constructor() {
    this.db = DB.dbInstance
  }

  async init() {
    try {
      const rs = await this.db?.store?.querySql("SELECT * FROM config LIMIT 1")
      if (rs === undefined || rs.rowCount <= 0) {
        return 0;
      } else {
        rs.goToFirstRow()
        this.backupType = rs.getLong(rs.getColumnIndex("backup_type"))
        this.backupRootPath = rs.getString(rs.getColumnIndex("backup_root_path"))
        this.dirRule = rs.getString(rs.getColumnIndex("dir_rule")) as DirRule
        this.lowBatteryStop = rs.getLong(rs.getColumnIndex("low_battery_stop"))
        this.onlyWifi = rs.getLong(rs.getColumnIndex("only_wifi_backup"))
        this.updatedAt = rs.getLong(rs.getColumnIndex("updated_at"))
        rs.close();
        if (this.backupRootPath == "") return 3;
        return 1;
      }
    } catch (err) {
      console.error(`Failed to add config. Code is ${err.code}, message is ${err.message}`);
      return 2;
    }

  }

  // 更新配置项
  async update() {
    const updateBucket: relationalStore.ValuesBucket = {
      "backup_type": this.backupType,
      "backup_root_path": this.backupRootPath,
      "dir_rule": this.dirRule,
      "low_battery_stop": this.lowBatteryStop,
      "only_wifi_backup": this.onlyWifi,
      "updated_at": Math.floor(Date.now() / 1000)
    };
    let predicates = new relationalStore.RdbPredicates("config");
    try {
      const rows = await this.db?.store?.update(updateBucket, predicates,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
      if (this.backupRootPath !== "") {
        return false;
      }
      console.info(`config Updated row count: ${rows}`);
      return true;
    } catch (err) {
      console.error(`config Updated failed, code is ${err.code},message is ${err.message}`);
      return false;
    }
  }
}