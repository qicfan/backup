import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';

const STORE_CONFIG :relationalStore.StoreConfig = {
  name: 'backup.db', // 数据库文件名
  securityLevel: relationalStore.SecurityLevel.S3, // 数据库安全级别
  allowRebuild: true
};

export class DB {
  public store: relationalStore.RdbStore | null = null
  private isInit: boolean = false;
  private static _instance: DB | null = null;

  static getInstance() {
    if (DB._instance === null) {
      DB._instance = new DB();
    }
    return DB._instance;
  }

  constructor() {
  }

  public static init(context: Context) {
    return new Promise((resolve: (rs: boolean) => void, reject: (reason: Error) => void) => {
      if (DB.getInstance().isInit) {
        return resolve(true);
      }
      relationalStore.getRdbStore(context, STORE_CONFIG, (err, store) => {
        if (err) {
          console.error(`Failed to get RdbStore. Code:${err.code}, message:${err.message}`);
          return reject(err);
        }
        console.info('Succeeded in getting RdbStore.');
        DB.getInstance().store = store
        // 当数据库创建时，数据库默认版本为0
        if (store.version === 0) {
          const CREATE_CONFIG_TABLE = "CREATE TABLE config (\n" +
            "    backup_type      INTEGER    DEFAULT (1),\n" +
            "    backup_root_path TEXT (256),\n" +
            "    dir_rule         TEXT,\n" +
            "    low_battery_stop INTEGER    DEFAULT (1),\n" +
            "    only_wifi_backup INTEGER    DEFAULT (1),\n" +
            "    auto INTEGER    DEFAULT (1),\n" +
            "    first INTEGER    DEFAULT (0),\n" +
            "    created_at       INTEGER,\n" +
            "    updated_at       INTEGER\n" +
            ");\n"
          const CREATE_TASK_TABLE = "CREATE TABLE task (\n" +
            "    id         INTEGER PRIMARY KEY AUTOINCREMENT,\n" +
            "    type       INTEGER DEFAULT (1),\n" +
            "    size       INTEGER DEFAULT (0),\n" +
            "    uploaded_size     INTEGER,\n" +
            "    total      INTEGER DEFAULT (0),\n" +
            "    success    INTEGER DEFAULT (0),\n" +
            "    failed     INTEGER DEFAULT (0),\n" +
            "    status     INTEGER DEFAULT (0),\n" +
            "    cancel_reason    TEXT (1024),\n" +
            "    created_at INTEGER,\n" +
            "    updated_at INTEGER\n" +
            ");";
          const CREATE_TASK_ITEMS_TABLE = "CREATE TABLE task_items (\n" +
            "    id         INTEGER PRIMARY KEY AUTOINCREMENT,\n" +
            "    task_id     INTEGER,\n" +
            "    name    TEXT (1024),\n" +
            "    uri    TEXT (1024),\n" +
            "    file_uri    TEXT (1024),\n" +
            "    remote_uri  TEXT (512),\n" +
            "    video_uri  TEXT (512),\n" +
            "    remote_video_uri  TEXT (512),\n" +
            "    video_size  INTEGER DEFAULT (0),\n" +
            "    failed_reason  TEXT (512),\n" +
            "    photo_type     INTEGER,\n" +
            "    sub_type     INTEGER,\n" +
            "    size     INTEGER,\n" +
            "    uploaded_size     INTEGER,\n" +
            "    status     INTEGER DEFAULT (0),\n" +
            "    date_added     INTEGER DEFAULT (0),\n" +
            "    date_modified     INTEGER DEFAULT (0),\n" +
            "    created_at INTEGER,\n" +
            "    uploaded_at INTEGER\n" +
            ");";
          const dateNow = Math.floor(Date.now() / 1000);
          const configIniSql = `INSERT INTO config VALUES (1, '', 'yyyy/mm/dd', 1, 1, 2, 0, ${dateNow}, 0)`;
          try {
            store.executeSql(CREATE_CONFIG_TABLE);
            console.log("config table created.")
          } catch (e) {
            const err = e as BusinessError
            console.error("config table create error." + `code: ${err.code}, msg: ${err.message}`)
          }
          try {
            store.executeSql(CREATE_TASK_TABLE);
            console.log("task table created.")
          } catch (e) {
            const err = e as BusinessError
            console.error("task table create error." + `code: ${err.code}, msg: ${err.message}`)
          }
          try {
            store.executeSql(CREATE_TASK_ITEMS_TABLE);
            console.log("task_items table created.")
          } catch (e) {
            const err = e as BusinessError
            console.error("task_items table create error." + `code: ${err.code}, msg: ${err.message}`)
          }
          try {
            store.executeSql(configIniSql);
            console.log("config table init.")
          } catch (e) {
            const err = e as BusinessError
            console.error("config table data create error." + `code: ${err.code}, msg: ${err.message}`)
          }
          // 设置数据库的版本，入参为大于0的整数
          store.version = 1;
        }
        DB.getInstance().isInit = true;
        return resolve(true);
      })
    })

  }
}
