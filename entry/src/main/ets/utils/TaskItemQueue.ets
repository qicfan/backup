import { TaskItemStatus } from '../typing'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { TaskItem } from '../models/TaskItem'
import { relationalStore } from '@kit.ArkData'
import { DB } from '../models/DB'
import { http } from '@kit.NetworkKit'
import { ApiResponse, HttpResp, PathExists } from './server'
import { taskpool, url } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { Checksum } from './tools'

@Sendable
export class TaskItemSendable {
  uri: string = ""
  photoType: number = photoAccessHelper.PhotoType.IMAGE
  subType: number = photoAccessHelper.PhotoSubtype.DEFAULT
  name: string = ""
  createdAt: number = 0
  uploadedAt: number = 0
  dateAdded: number = 0
  dateModified: number = 0
  size: number = 0
  videoSize: number = 0
  status: number = TaskItemStatus.WAIT
  fileUri: string = ""
  remoteUri: string = ""
  videoUri: string = ""
  remoteVideoUri: string = ""
  checksum: string = ""

  server: string = ""
  token: string = ""
  backupRootPath: string = ""
  index: number = 0

  static getInstance(item: TaskItem, serverHost: string, token: string, backupRootPath: string, index: number) {
    let self = new TaskItemSendable()
    self.server = serverHost
    self.token = token
    self.backupRootPath = backupRootPath
    self.index = index
    self.uri = item.uri
    self.photoType = item.photoType
    self.subType = item.subType
    self.name = item.name
    self.createdAt = item.createdAt
    self.uploadedAt = item.uploadedAt
    self.dateAdded = item.dateAdded
    self.dateModified = item.dateModified
    self.size = item.size
    self.videoSize = item.videoSize
    self.status = item.status
    self.fileUri = item.fileUri
    self.videoUri = item.videoUri
    self.remoteUri = item.remoteUri
    self.remoteVideoUri = item.remoteVideoUri
    return self
  }

  getItem(): TaskItem {
    let item = new TaskItem()
    item.uri = this.uri
    item.photoType = this.photoType
    item.subType = this.subType
    item.name = this.name
    item.createdAt = this.createdAt
    item.uploadedAt = this.uploadedAt
    item.dateAdded = this.dateAdded
    item.dateModified = this.dateModified
    item.size = this.size
    item.videoSize = this.videoSize
    item.status = this.status
    item.fileUri = this.fileUri
    item.videoUri = this.videoUri
    item.remoteUri = this.remoteUri
    item.remoteVideoUri = this.remoteVideoUri
    item.checksum = this.checksum
    return item
  }

  async save() {
    const item = await TaskItem.getByUri(this.uri);
    if (item !== undefined) {
      // 已经存在了，不处理
      return false;
    }
    const insertBucket: relationalStore.ValuesBucket = {
      "task_id": 0,
      "name": this.name,
      "uri": this.uri,
      "size": this.size,
      "video_size": this.videoSize,
      "uploaded_size": 0,
      "file_uri": this.fileUri,
      "remote_uri": this.remoteUri,
      "video_uri": this.videoUri,
      "remote_video_uri": this.remoteVideoUri,
      "failed_reason": "",
      "photo_type": this.photoType,
      "sub_type": this.subType,
      "status": this.status,
      "created_at": this.createdAt,
      "uploaded_at": this.uploadedAt,
      "date_added": this.dateAdded,
      "date_modified": this.dateModified,
    };
    try {
      await DB.getInstance().store?.insert(TaskItem.TABLE_NAME, insertBucket,
        relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
      return true;
    } catch (err) {
      console.error(`task items ${this.remoteUri} insert failed, code is ${err.code},message is ${err.message}`);
      return false;
    }
  }

  getRelPath(pathOrFile: string) {
    return `${this.backupRootPath}/${pathOrFile}`
  }

  async exists(pathOrFile: string, hasBackupRoot: boolean = false, isPath: boolean = true) {
    let data: Record<string, string> = {}
    let header: Record<string, string> = {}
    let relPath: string = pathOrFile
    if (isPath) {
      data["pathType"] = "1"
      if (!hasBackupRoot) {
        relPath = this.getRelPath(pathOrFile)
      }
      data["path"] = relPath
      header["X-Pre-Checksum"] = ""
    } else {
      data["pathType"] = "2"
      data["path"] = pathOrFile
    }
    let resp: HttpResp<PathExists> = await this.request<PathExists>("/api/exists", http.RequestMethod.POST, header, data)
    if (!resp || !resp.success || !resp.result) {
      console.warn(`${this.index} 查询目录或文件 ${pathOrFile} 是否存在时失败：${resp.message}`)
      return false
    }
    return resp.result.data.exists
  }

  async checksumExists() {
    let checksum = await Checksum(this.uri, this.size) as string
    this.checksum = checksum
    // console.log(`文件的checksum: ${checksum}`)
    let data: Record<string, string> = {}
    let header: Record<string, string> = {"X-Checksum": checksum}
    let resp: HttpResp<PathExists> = await this.request<PathExists>("/api/exists-checksum", http.RequestMethod.POST, header, data)
    // console.log(JSON.stringify(resp.result))
    if (!resp || !resp.success || !resp.result) {
      console.warn(`${this.index} 查询目录或文件 ${this.uri} 是否存在时失败：${resp.message}`)
      return false
    }
    return resp.result.data.exists
  }

  async request<T>(urlPath: string, method: http.RequestMethod, headers: Record<string, string> | null, data: Record<string, string>): Promise<HttpResp<T>> {
    return new Promise((resolve, reject) => {
      let httpRequest = http.createHttp();
      try {
        let urlBase = `${this.server}${urlPath}`
        if (method == http.RequestMethod.GET && data) {
          let queryParams = new url.URLParams(data)
          urlBase += '?' + queryParams.toString()
        }
        if (headers == null) {
          headers = {}
        }
        let token = this.token
        if (token !== "") {
          headers["Authorization"] = "Bearer " + token
        }
        // 构造http请求
        let options: http.HttpRequestOptions = {
          method: method,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 5000,
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