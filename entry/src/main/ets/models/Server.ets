import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

const PASSWORD_ALIAS = "backup_password"

export function stringToArray(str: string): Uint8Array {
  let textEncoder = new util.TextEncoder();
  return textEncoder.encodeInto(str);
}

export function arrayToString(arr: Uint8Array): string {
  let textDecoder = util.TextDecoder.create("utf-8", { ignoreBOM: true });
  let str = textDecoder.decodeToString(arr, { stream: false })
  return str;
}

export class NotFoundServer implements BusinessError {
  code: number = 404
  name: string = "服务器不存在"
  message: string = "服务器不存在"
}

/**
 * 服务器配置
 * 包括服务器地址、用户名、密码
 */
@ObservedV2
export class ServerConfig {
  server: string = ""
  username: string = ""
  password: string = ""

  private static _instance: ServerConfig | null = null;

  static getInstance() {
    if (ServerConfig._instance === null) {
      ServerConfig._instance = new ServerConfig();
    }
    return ServerConfig._instance;
  }

  constructor() {
  }

  // 查询服务器
  async queryAsset() {
    try {
      let query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, stringToArray(PASSWORD_ALIAS)); // 指定了关键资产别名，最多查询到一条满足条件的关键资产
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL); // 此处表示需要返回关键资产的所有信息，即属性+明文
      const res = await asset.query(query);
      // console.log(`查询到 ${res.length} 条关键资产`)
      if (res.length === 0) return false;
      for (let i = 0; i < res.length; i++) {
        let secret: Uint8Array = res[i].get(asset.Tag.SECRET) as Uint8Array;
        this.password = arrayToString(secret);
        let usernameU8A: Uint8Array = res[i].get(asset.Tag.DATA_LABEL_NORMAL_1) as Uint8Array
        this.username = arrayToString(usernameU8A);
        let serverU8A: Uint8Array = res[i].get(asset.Tag.DATA_LABEL_NORMAL_2) as Uint8Array
        this.server = arrayToString(serverU8A);
        return true;
      }
      return false;
    } catch (err) {
      console.log(`查询服务器失败，code=${err.code}, msg=${err.message}`)
      return false;
    }
  }

  async addOrUpdateAsset(server: string, username: string, password: string) {
    const exists = await this.queryAsset();
    if (!exists) {
      await this.addAsset(server, username, password)
    } else {
      await this.updateAsset(server, username, password)
    }
  }

  /**
   * 将服务器添加到关键资产中
   */
  async addAsset(server: string, username: string, password: string) {
    let attr: asset.AssetMap = new Map();
    attr.set(asset.Tag.SECRET, stringToArray(password));
    attr.set(asset.Tag.ALIAS, stringToArray(PASSWORD_ALIAS));
    attr.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED); // 设备解锁状态可访问
    attr.set(asset.Tag.AUTH_TYPE, asset.AuthType.NONE) // 不需要认证即可访问数据
    attr.set(asset.Tag.IS_PERSISTENT, false) // 卸载应用时删除
    attr.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE) // 冲突时覆盖旧的
    attr.set(asset.Tag.DATA_LABEL_NORMAL_1, stringToArray(username)); // 用户名
    attr.set(asset.Tag.DATA_LABEL_NORMAL_2, stringToArray(server)); // 服务器地址
    await asset.add(attr)
    this.server = server
    this.username = username
    this.password = password
    console.info(`Asset added successfully.`);
  }

  /**
   * 将服务器添加到关键资产中
   */
  async updateAsset(server: string, username: string, password: string) {
    let attr: asset.AssetMap = new Map();
    attr.set(asset.Tag.SECRET, stringToArray(password));
    attr.set(asset.Tag.DATA_LABEL_NORMAL_1, stringToArray(username)); // 用户名
    attr.set(asset.Tag.DATA_LABEL_NORMAL_2, stringToArray(server)); // 服务器地址
    let query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, stringToArray(PASSWORD_ALIAS));
    await asset.update(query, attr)
    this.server = server
    this.username = username
    this.password = password
    console.info(`Asset updated successfully.`);
    // let err = error as BusinessError;
    // console.error(`Failed to updated Asset. Code is ${err.code}, message is ${err.message}`);
  }

  async remove() {
    let query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, stringToArray(PASSWORD_ALIAS));
    return await asset.remove(query)
  }
}
