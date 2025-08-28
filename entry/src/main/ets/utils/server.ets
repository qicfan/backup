import { ServerConfig } from "../models/Server";
import { http } from "@kit.NetworkKit";
import { url } from "@kit.ArkTS";
import { BusinessError } from "@kit.BasicServicesKit";
import { Config } from "../models/Config";
import { urlSafeBase64 } from "./tools";
import { fileIo } from "@kit.CoreFileKit";

export interface HttpResp<T> {
  success: boolean
  message: string
  result: ApiResponse<T> | undefined
  resp: http.HttpResponse | undefined
}

export interface ApiResponse<T> {
  code: number
  message: string
  data: T
}
export interface Token {
  token: string
}

export interface DirItem {
  name: string
  relPath: string
  isDir: boolean
}

export interface PathExists {
  exists: boolean;
}

export interface PathItem {
  path: string
}

export class BackupServer {
  private server: ServerConfig = ServerConfig.getInstance();
  private config: Config = Config.getInstance()

  private static _instance: BackupServer | null = null;

  static getInstance() {
    if (BackupServer._instance === null) {
      BackupServer._instance = new BackupServer();
    }
    return BackupServer._instance;
  }

  constructor() {
  }

  updateConfig(serverConfig: ServerConfig, config?: Config) {
    this.server = serverConfig
    if (config !== undefined) {
      this.config = config
    }
  }

  // 登录
  async login(): Promise<HttpResp<Token>> {
    let resp: HttpResp<Token> = {
      success: false,
      message: "",
      result: undefined,
      resp: undefined
    }
    if (!this.server || this.server.username == "" || this.server.password == "") {
      resp.message = "服务器参数错误，用户名和密码不能为空"
      return resp
    }
    let bodyMap: Record<string, string> = {"username": this.server.username, "password": this.server.password}

    resp = await this.post<Token>("/login", null, bodyMap)
    if (resp.success && resp.result) {
      this.saveToken(resp.result.data.token)
    }
    return resp
  }

  // 验证token是否正常
  async valid(): Promise<boolean> {
    return this.exists("/")
  }

  // pathOrFile在服务端是否存在
  async exists(pathOrFile: string): Promise<boolean> {
    let relPath = this.getRelPath(pathOrFile)
    let data: Record<string, string> = {"path": relPath}
    let resp: HttpResp<PathExists> = await this.post<PathExists>("/api/exists", null, data)
    if (!resp || !resp.success || !resp.result) {
      console.warn(`查询目录或文件 ${relPath} 是否存在时失败：${resp.message}`)
      return false
    }
    return resp.result.data.exists
  }

  // basePath下的子目录列表
  async dirList(path: string): Promise<DirItem[]>{
    let data: Record<string, string> = {"path": path}
    let resp: HttpResp<DirItem[]> = await this.post<DirItem[]>("/api/listdir", null, data)
    console.log(JSON.stringify(resp))
    if (!resp || !resp.success || !resp.result) {
      console.warn(`查询目录或文件 ${path} 的子目录列表时失败：${resp.message}`)
      return []
    }

    return resp.result.data
  }

  // 创建目录
  async createDir(parentPath: string, name: string): Promise<HttpResp<PathItem>> {
    let parentRelPath = this.getRelPath(parentPath)
    let data: Record<string, string> = {"parent": parentPath, "name": name}
    let resp: HttpResp<PathItem> = await this.post<PathItem>("/api/createdir", null, data)
    return resp
    // if (!resp || !resp.success || !resp.result) {
    //   console.warn(`创建目录 ${parentRelPath}/${name} 时失败：${resp.message}`)
    //   return ""
    // }
    // return resp.result.data.path
  }

  // 返回缩略图的URL
  // size格式：100x100
  async getThumbnailUrl(path: string, size: string) {
    let encodePath = urlSafeBase64(path)
    return `${this.server}/photo/thumbnail/${encodePath}/${size}`
  }

  // 从数据库中读取token，然后缓存到内存中
  public getToken(): string | undefined {
    return this.config?.accessToken
  }

  // 存放到数据库中，然后更新缓存
  public saveToken(token: string) {
    this.config?.updateAccessToken(token)
  }

  public getRelPath(pathOrFile: string) {
    return `${this.config?.backupRootPath}/${pathOrFile}`
  }

  async post<T>(urlPath: string, headers: Record<string, string> | null, data: Record<string, string>) {
    return this.requestWithRetry<T>(urlPath, http.RequestMethod.POST, headers, data)
  }

  async get<T>(urlPath: string, headers: Record<string, string> | null, data: Record<string, string>) {
    return this.requestWithRetry<T>(urlPath, http.RequestMethod.GET, headers, data)
  }

  // 发送请求
  // 支持三次重试
  // 如果token失效责重新登录然后重试
  //
  async requestWithRetry<T>(urlPath: string, method: http.RequestMethod, headers: Record<string, string> | null, data: Record<string, string>): Promise<HttpResp<T>> {
    let lastResp: HttpResp<T> = {
      success: false,
      message: "",
      resp: undefined,
      result: undefined
    }
    for (let i=0; i<3; i++) {
      try {
        lastResp = await this.request(urlPath, method, headers, data);
        if (lastResp.success) {
          return lastResp;
        }
        if (lastResp?.resp?.responseCode == http.ResponseCode.UNAUTHORIZED) {
          console.error(`${method} ${urlPath} 失败: token已过期，重新登录后重试`)
          // token过期
          this.login() // 获取token,然后重试
        }
        if (lastResp.resp?.responseCode == http.ResponseCode.INTERNAL_ERROR) {
          console.error(`${method} ${urlPath} 失败: ${lastResp.message}`)
        }
      } catch (e) {
        console.error(`${method} ${urlPath} 失败: ${e.message}`)
        lastResp.message = e.message
      }
      console.warn(`${method} ${urlPath} 失败，进行第 ${i+1} 次重试`)
    }
    return lastResp
  }

  async request<T>(urlPath: string, method: http.RequestMethod, headers: Record<string, string> | null, data: Record<string, string>): Promise<HttpResp<T>> {
    return new Promise((resolve, reject) => {
      let httpRequest = http.createHttp();
      try {
        let urlBase = `${this.server.server}${urlPath}`
        let urlObj = url.URL.parseURL(urlBase)
        if (method == http.RequestMethod.GET && data) {
          let queryParams = new url.URLParams(data)
          urlBase += '?' + queryParams.toString()
        }
        if (headers == null) {
          headers = {}
        }
        let token = this.getToken();
        if (token !== "") {
          headers["Authorization"] = "Bearer " + token
        }
        // 构造http请求
        let options: http.HttpRequestOptions = {
          method: method,
          expectDataType: http.HttpDataType.STRING
        }
        if (method == http.RequestMethod.POST && data) {
          // 发送json格式的数据
          headers["Content-Type"] = "application/json"
          options.extraData = JSON.stringify(data)
        }
        options.header = headers
        httpRequest.request(urlBase, options).then((resp: http.HttpResponse) => {
          // 解析结果
          let result = JSON.parse(resp.result as string) as ApiResponse<T>
          let httpResp: HttpResp<T> = {
            success: result.code === 0,
            message: result.message,
            resp: resp,
            result: result
          }
          resolve(httpResp);
        }).catch((e: BusinessError) => {
          let httpResp: HttpResp<T> = {
            success: false,
            message: e.message,
            resp: undefined,
            result: undefined
          }
          resolve(httpResp)
        })
      } catch (err) {
        reject(err)
      }
    })

  }
}

// 下载文件到沙箱路径
@Concurrent
export async function download(path: string, destPathOrFile: string, isLive: boolean, token: string, baseUrl: string, backupRootPath: string, progress: (info: http.DataReceiveProgressInfo)=>void): Promise<boolean> {
  return new Promise((resolve, reject) => {
    let relPath = `${backupRootPath}/${path}`
    // 将文件下载到destPathOrFile
    try {
      let urlObj = new url.URL()
      urlObj.host = baseUrl
      urlObj.pathname = "/photo/download"
      urlObj.params.set("path", relPath)
      urlObj.params.set("cos", "HMOS")
      urlObj.params.set("is_live", isLive ? "1" : "0")
      let realUrl = urlObj.toString()
      let headers: Record<string, string> = {}
      headers["Authorization"] = "Bearer " + token
      // 构造http请求
      let options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING
      }
      // 打开目标文件
      let destFile = fileIo.openSync(destPathOrFile, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
      // 大文件下载建议方案
      const httpRequest = http.createHttp()
      httpRequest.on("dataReceive", (data: ArrayBuffer) => {
        // 写入文件
        fileIo.writeSync(destFile.fd, data);
      })
      httpRequest.on("dataReceiveProgress", (info: http.DataReceiveProgressInfo) => {
        // 计算进度
        return progress(info)
      })
      httpRequest.on("dataEnd", () => {
        // 取消订阅事件
        httpRequest.off("dataReceive")
        httpRequest.off("dataReceiveProgress")
        httpRequest.off("dataEnd")
        // 关闭文件
        fileIo.closeSync(destFile.fd)
        // 返回
        resolve(true)
      })
      httpRequest.requestInStream(
        realUrl,
        options
      );
    } catch (e) {
      reject(e)
    }
  })
}