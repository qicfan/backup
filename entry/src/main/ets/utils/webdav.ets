import { rcp } from "@kit.RemoteCommunicationKit";
import { ServerConfig } from "../models/Server";
import { xml, util } from '@kit.ArkTS';
import { DavResource, SERVER_AUTH_FAILED_EVENT } from "../typing";
import { emitter } from "@kit.BasicServicesKit";
import fileIo from "@ohos.file.fs";
import { deletePhoto } from "./tools";
import { TaskItem } from "../models/TaskItem";
import { Task } from "../models/Task";

export class RequestReturn {
  success: boolean = true;
  statusCode: number = 200;
  message: string = "";
  data: DavResource[] = [];
  body: string = ""
}

@ObservedV2
export class WebDavResource implements DavResource {
  href: string = ""
  displayName: string = ""
  type: string = ""
}

export class WebDav {
  private session: rcp.Session | null = null;
  private server: ServerConfig = new ServerConfig();

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
      headers: { "Accept": "text/plain,application/xml" },
      requestConfiguration: {
        transfer: {
          timeout: { connectMs: 3000 }
        },
        security: {
          serverAuthentication: {
            credential: {
              username: this.server.username,
              password: this.server.password
            },
            authenticationType: "basic"
          }
        }
      }
    });
  }

  public close() {
    this.session?.close();
  }

  // 发送请求
  async request(req: rcp.Request) {
    const requestReturn: RequestReturn = new RequestReturn();
    try {
      const resp = await this.session?.fetch(req);
      if (resp === undefined) {
        throw new Error("请求失败")
      }
      requestReturn.statusCode = resp.statusCode;
      if (resp.statusCode === 401) {
        requestReturn.message = "用户名密码不正确"
        requestReturn.success = false;
        // 触发登录失败事件
        emitter.emit(SERVER_AUTH_FAILED_EVENT);
      }

      if (resp.statusCode === 500) {
        requestReturn.message = "服务器内部错误，请检查服务器是否正常。"
        requestReturn.success = false;
      }
      if (resp.statusCode === 407) {
        requestReturn.message = "目录不存在，请先创建目录"
        requestReturn.success = false;
      }
      if(resp.statusCode === 507) {
        requestReturn.message = "服务器存储空间不足"
        requestReturn.success = false;
      }
      if (requestReturn.statusCode >= 200 && requestReturn.statusCode < 300) {
        // 正常
        requestReturn.statusCode = 200
        requestReturn.body = resp.toString() ?? "";
        requestReturn.success = true;
      } else {
        requestReturn.success = false;
      }
    } catch (err) {
      requestReturn.statusCode = 500
      requestReturn.success = false;
      if (err.code === 1007900028) {
        requestReturn.message = "服务器超时，请检查服务器地址或端口是否正确"
      } else {
        requestReturn.message = "连接失败，请检查本机网络或者联系作者，错误码：" + err.code + ", 错误：" + err.message
      }
    }
    return requestReturn;
  }

  // 验证服务器和验证方式是否可用
  public async valid() {
    const req = new rcp.Request('/', "PROPFIND", { "Depth": "0" });
    return await this.request(req);
  }

  // 读取目录下的所有文件夹
  async getDirs(path: string = '/') {
    const body = "<?xml version=\"1.0\"?>\n" +
      "<d:propfind xmlns:d=\"DAV:\">\n" +
      "  <d:prop>\n" +
      "    <d:resourcetype/>\n" +
      "    <d:displayname/>\n" +
      "  </d:prop>\n" +
      "</d:propfind>"
    const req = new rcp.Request(path, "PROPFIND", { "Depth": "1" }, body);
    const rr = await this.request(req);
    if (rr.statusCode === 200) {
      const items = this.parseXml(rr.body);
      const dirs: WebDavResource[] = [];
      items.forEach((item: WebDavResource) => {
        if (item.type === 'collection') {
          dirs.push(item)
        }
      })
      rr.data = dirs;
    }
    return rr;
  }

  // 是否存在
  async exists(path: string) {
    const body = "<?xml version=\"1.0\"?>\n" +
      "<d:propfind xmlns:d=\"DAV:\">\n" +
      "  <d:prop>\n" +
      "    <d:resourcetype/>\n" +
      "  </d:prop>\n" +
      "</d:propfind>"
    const req = new rcp.Request(path, "PROPFIND", { "Depth": "0" }, body);
    const rr = await this.request(req);
    if (rr.statusCode === 200) {
      return true;
    }
    return false;
  }

  // 创建目录
  async mkDir(path: string) {
    const req = new rcp.Request(path, "MKCOL");
    return await this.request(req);
  }

  // 删除文件
  async delete(path: string) {
    const req = new rcp.Request(path, "DELETE");
    return await this.request(req);
  }

  async upload(taskItem: TaskItem, type: string = "default"): Promise<boolean> {
    // 读取文件
    let uploadFile: fileIo.File;
    let uploadBuffer: ArrayBuffer;
    if (type === "default") {
      uploadBuffer = new ArrayBuffer(taskItem.size);
    } else {
      const stat = fileIo.statSync(taskItem.videoUri)
      uploadBuffer = new ArrayBuffer(stat.size);
    }
    try {
      uploadFile = fileIo.openSync(type === "default" ? taskItem.fileUri : taskItem.videoUri, fileIo.OpenMode.READ_ONLY);
      fileIo.readSync(uploadFile.fd, uploadBuffer);
    } catch (err) {
      console.error(`读取要上传的文件失败. 文件路径：${type === "default" ? taskItem.fileUri : taskItem.videoUri}, Code: ${err.code}, message: ${err.message}`);
      return false;
    }
    const customHttpEventsHandler: rcp.HttpEventsHandler = {
      onUploadProgress: (totalSize: number, transferredSize: number) => {
        if (type === 'default') {
          taskItem.updateUploadedSize(transferredSize)
          taskItem.task.updateUploadedSize(transferredSize)
        }
      }
    };
    let url: string;
    if (type === 'default') {
      url = `${taskItem.config.backupRootPath}/${taskItem.remoteUri}`
    } else {
      url = `${taskItem.config.backupRootPath}/${taskItem.videoRemoteUri}`
    }
    // console.log(`要上传的文件：${taskItem.fileUri}, 远程路径：${taskItem.remoteUri}, url: ${url}`)
    const req = new rcp.Request(url, "PUT", {}, uploadBuffer, {}, {}, {tracing: {httpEventsHandler: customHttpEventsHandler} });
    const rr = await this.request(req);
    if (rr.success) {
      console.info("上传成功:" + (type === "default" ? taskItem.fileUri : taskItem.videoUri) + ', ' + rr.statusCode);
      if (type === 'default') {
        taskItem.updateUploadedSize(taskItem.size)
        taskItem.task.updateUploadedSize(taskItem.size)
      }
      taskItem.success();
      fileIo.close(uploadFile)
      uploadBuffer = new ArrayBuffer(0);
      deletePhoto(type === "default" ? taskItem.fileUri : taskItem.videoUri);
      return true;
    }
    console.error(`Failed to request the upload. Code: ${rr.statusCode}, message: ${rr.message}`);
    taskItem.failed();
    fileIo.close(uploadFile)
    uploadBuffer = new ArrayBuffer(0);
    deletePhoto(type === "default" ? taskItem.fileUri : taskItem.videoUri)
    return false;
  }

  // 解析dav xml
  parseXml(xmlStr: string | null): WebDavResource[] {
    let textEncoder: util.TextEncoder = new util.TextEncoder();
    let arrBuffer: Uint8Array = textEncoder.encodeInto(xmlStr); // 对数据编码，防止包含中文字符乱码
    let that: xml.XmlPullParser = new xml.XmlPullParser(arrBuffer.buffer as object as ArrayBuffer, 'UTF-8');
    let items: WebDavResource[] = []
    let curItem: WebDavResource = new WebDavResource()
    let rtqz: boolean = false;
    let dpqz: boolean = false;
    let hrefqz: boolean = false;

    let options: xml.ParseOptions = {
      supportDoctype: true,
      ignoreNameSpace: true,
      tokenValueCallbackFunction: (name: xml.EventType, value: xml.ParseInfo) => {
        if (value.getName() === "D:href" && name === 2) {
          hrefqz = true;
          return true;
        }
        if (hrefqz && value.getName() === "" && name === 4) {
          curItem.href = value.getText()
          hrefqz = false;
          return true;
        }
        if (value.getName() === "D:resourcetype" && name === 2) {
          rtqz = true;
          return true;
        }
        if (rtqz === true && name === 2 && value.getText() === "") {
          curItem.type = value.getName().replace('D:', '')
          rtqz = false;
          return true;
        }
        if (value.getName() === "D:displayname" && name === 2) {
          dpqz = true
          return true;
        }
        if (dpqz === true) {
          if (value.getName() === 'D:displayname') {
            curItem.displayName = "";
          } else {
            curItem.displayName = value.getText();
          }
          dpqz = false

          return true;
        }
        if (value.getName() == "D:status" && value.getDepth() === 4 && name === 2) {
          // 结束
          items.push(curItem)
          curItem = new WebDavResource()
        }
        return true; //true:继续解析 false:停止解析
      },
    };
    that.parseXml(options);
    items.splice(0, 1)
    return items;
  }
}