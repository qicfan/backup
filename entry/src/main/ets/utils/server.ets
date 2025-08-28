import { rcp } from "@kit.RemoteCommunicationKit";
import { ServerConfig } from "../models/Server";

export class BackupServer {
  public session: rcp.Session | null = null;
  public server: ServerConfig | null = null;

  private static _instance: BackupServer | null = null;

  static getInstance() {
    if (BackupServer._instance === null) {
      BackupServer._instance = new BackupServer();
    }
    return BackupServer._instance;
  }

  constructor(serverConfig?: ServerConfig) {
    if (serverConfig !== undefined) {
      this.updateSerConfig(serverConfig)
    }
  }

  public updateSerConfig(serverConfig: ServerConfig) {
    this.server = serverConfig;
    this.session?.close()
    this.session = rcp.createSession({
      baseAddress: this.server.server,
      headers: { "Accept": "text/json,application/json" },
      requestConfiguration: {
        transfer: {
          timeout: { connectMs: 3000 }
        }
      }
    });
  }

  public close() {
    this.session?.close();
  }

  public login() {}

  // 登录获得token
  public getToken() {

  }

  // 发送请求
  // async request(req: rcp.Request) {
  //   const requestReturn: RequestReturn = new RequestReturn();
  //   try {
  //     const resp = await this.session?.fetch(req);
  //     if (resp === undefined) {
  //       requestReturn.statusCode = 500;
  //       requestReturn.success = false;
  //       requestReturn.message = "请求失败"
  //       return requestReturn;
  //     }
  //     console.log(resp.statusCode + "")
  //     console.log(JSON.stringify(resp.headers));
  //     // 输出响应的body内容，resp.body为ArrayBuffer类型
  //     const decoder = new util.TextDecoder();
  //     let body: string = decoder.decodeToString(new Uint8Array(resp.body));
  //     console.log(body)
  //     requestReturn.statusCode = resp.statusCode;
  //     requestReturn.headers = resp.headers;
  //     requestReturn.body = body
  //     if (resp.statusCode === 401) {
  //       requestReturn.message = "用户名密码不正确"
  //       requestReturn.success = false;
  //       // 触发登录失败事件
  //       emitter.emit(SERVER_AUTH_FAILED_EVENT);
  //     }
  //     if (resp.statusCode === 409) {
  //       requestReturn.message = "权限不足"
  //       requestReturn.success = false;
  //     }
  //     if (resp.statusCode === 405) {
  //       requestReturn.message = "已存在"
  //       requestReturn.success = false;
  //     }
  //
  //     if (resp.statusCode === 500) {
  //       requestReturn.message = "服务器内部错误，请检查服务器是否正常。"
  //       requestReturn.success = false;
  //     }
  //     if (resp.statusCode === 407) {
  //       requestReturn.message = "目录不存在，请先创建目录"
  //       requestReturn.success = false;
  //     }
  //     if (resp.statusCode === 507) {
  //       requestReturn.message = "服务器存储空间不足"
  //       requestReturn.success = false;
  //     }
  //     if (requestReturn.statusCode >= 200 && requestReturn.statusCode < 300) {
  //       // 正常
  //       requestReturn.statusCode = 200
  //       // requestReturn.body = resp.toString() ?? "";
  //       requestReturn.success = true;
  //     } else {
  //       requestReturn.success = false;
  //     }
  //   } catch (err) {
  //     requestReturn.statusCode = 500
  //     requestReturn.success = false;
  //     if (err.code === 1007900028) {
  //       requestReturn.message = "服务器超时，请检查服务器地址或端口是否正确"
  //     } else {
  //       requestReturn.message = "连接失败，请检查本机网络或者联系作者，错误码：" + err.code + ", 错误：" + err.message
  //     }
  //   }
  //   return requestReturn;
  // }

}