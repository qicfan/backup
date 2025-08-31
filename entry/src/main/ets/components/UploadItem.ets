import { UploadQueue } from "../utils/UploadQueue";
import { AppStorageV2 } from "@kit.ArkUI";
import { ErrorEvent, MessageEvents, worker } from "@kit.ArkTS";
import { ApiResponse, BackupServer, PathItem } from "../utils/server";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { Photos } from "../utils/photos";
import { UploadEvent } from "../typing";
import { Config } from "../models/Config";
import { ServerConfig } from "../models/Server";
import { formatFileSize, splitFileExt } from "../utils/tools";
import { emitter } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";
import { TaskItem } from "../models/TaskItem";
import { IBestIcon, IBestProgress } from "@ibestservices/ibest-ui-v2";
import { fileIo } from "@kit.CoreFileKit";

@ComponentV2
export struct UploadItem {
  @Param index: number = 0
  @Param isEnd: boolean = false
  @Local uploadQueue: UploadQueue = AppStorageV2.connect(UploadQueue, "UploadQueue", () => UploadQueue.getInstance())!;
  @Local fileName: string = ""
  @Local fileSize: number = 0
  @Local speed: number = 0 // 字节，显示的时候需要格式化成MB
  @Local progress: number = 0; // 进度，百分比，0-100
  @Local isStop: boolean = false // 是否暂停
  private uploadWorker = new worker.ThreadWorker("entry/ets/workers/UploadWorker.ets")
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Local backupServer: BackupServer = AppStorageV2.connect(BackupServer, "BackupServer", () => BackupServer.getInstance())!;
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => ServerConfig.getInstance())!;
  @Event finish: (index: number) => void = () => {};
  private idle: boolean = true // 是否空闲，如果为true则从队列中继续获取数据
  private ctx: Context = getContext(this)
  private SI: number = 0
  private preSize: number = 0
  @Local isFinish: boolean = false
  aboutToAppear(): void {
    console.log(`线程 ${this.index} 开始初始化`)
    emitter.once(Global.STOP_TASK_EVENT, () => {
      // 如果触发停止事件则不继续循环上传
      this.isStop = true
    })
    // 开始执行
    this.idle = false
    this.process()
    // 从队列中获取一条数据，如果队列为空则等待1S继续
    this.SI = setInterval(() => {
      if (this.isStop) {
        clearInterval(this.SI)
      }
      if (this.idle) {
        console.log(`线程 ${this.index}： 空闲，开始从队列读取待备份内容并开始执行`)
        this.process().then((rs: number) => {
          console.log(`主线程是否查询数据完成： ${this.isEnd}`)
          if (rs === 2 && this.isEnd) {
            // 无法从队列中获取到数据
            this.isStop = true
            this.isFinish = true
            // 通知上层组件
            this.finish(this.index)
          }
        })
      } else {
        // console.log(`上传线程 ${this.index} 繁忙`)
      }

    }, 10)

  }

  aboutToDisappear(): void {
    // 销毁子线程
    console.log(`销毁子线程 ${this.index}`)
    this.uploadWorker.terminate()
  }

  async process() {
    let item = await this.uploadQueue.read()
    if (item === undefined) {
      console.log(`线程 ${this.index} 无法从队列中获取到数据，返回是否可以完成`)
      this.idle = true
      return 2
    }
    this.preSize = 0
    this.idle = false
    this.fileName = item.name
    this.fileSize = item.size
    let photoAsset: photoAccessHelper.PhotoAsset | undefined = await Photos.getPhotoAssetByUri(this.ctx, item.uri)
    if (photoAsset === undefined) {
      console.warn(`资源不存在无法上传：${item.uri}`)
      this.idle = true
      return 1
    }
    let token = this.backupServer.getToken()
    if (token === undefined) {
      console.warn("访问凭证不存在")
      this.idle = true
      return 1
    }
    if (item.subType == photoAccessHelper.PhotoSubtype.MOVING_PHOTO) {
      // 如果是动态照片则先将文件保存到本地沙箱目录
      let movingPhoto = await Photos.getMovingPhoto(this.ctx, photoAsset)
      await movingPhoto.requestContent(item.fileUri, item.videoUri)
      // 视频和普通照片责直接上传
      let uploadEvent: UploadEvent = {
        path: this.config.backupRootPath !== "" ? this.config.backupRootPath + '/' + item.remoteUri : item.remoteUri,
        type: 3,
        fileUri: item.fileUri,
        token: token,
        server: this.server.server,
        live_photo_video_path: this.config.backupRootPath !== "" ? this.config.backupRootPath + '/' + item.remoteVideoUri : item.remoteVideoUri,
      }
      await this.upload(item, uploadEvent, false)

      let uploadVideoEvent: UploadEvent = {
        path: this.config.backupRootPath !== "" ? this.config.backupRootPath + '/' + item.remoteVideoUri : item.remoteVideoUri,
        type: 3,
        fileUri: item.videoUri,
        token: token,
        server: this.server.server,
        live_photo_video_path: ""
      }
      this.fileName = splitFileExt(item.name)[1] + '.mp4'
      this.fileSize = item.videoSize
      await this.upload(item, uploadVideoEvent, true)
      // 删除本地文件
      await fileIo.unlink(item.fileUri)
      await fileIo.unlink(item.videoUri)
    } else {
      let fileUri = this.config.backupRootPath + '/' + item.remoteUri
      if (this.config.backupRootPath === "") {
        fileUri = item.remoteUri
      }
      // 视频和普通照片责直接上传
      let uploadEvent: UploadEvent = {
        path: fileUri,
        type: item.photoType == photoAccessHelper.PhotoType.IMAGE ? 1 : 2,
        fileUri: item.uri,
        token: token,
        server: this.server.server,
        live_photo_video_path: ""
      }
      await this.upload(item, uploadEvent, false)
    }
    this.idle = true
    return 0
    // // 在调用terminate后，执行onexit
    // this.uploadWorker.onexit = (code) => {
    //   console.info("main thread terminate");
    // }
    // // 监听Worker错误
    // this.uploadWorker.onerror = (err: ErrorEvent) => {
    //   console.error("main error message " + err.message);
    // }
  }

  async upload(item: TaskItem, uploadFile: UploadEvent, isMovingPhotoVideo: boolean): Promise<boolean> {
    return new Promise((resolve, reject) => {
      this.uploadWorker.postMessage(uploadFile)
      // 宿主线程接收worker线程信息
      this.uploadWorker.onmessage = async (e: MessageEvents) => {
        // data：worker线程发送的信息
        let data: ApiResponse<number[] | PathItem | undefined> = e.data as ApiResponse<number[] | PathItem | undefined>;
        // console.info("main thread data is  " + JSON.stringify(data));
        if(data.code === 0) {
          // 上传成功
          console.log(`线程${this.index}: ${item.id} => ${item.remoteUri}上传成功`)
          await item.success()
          resolve(true)
          return
        }
        if (data.code === 2) {
          // 进度回调
          let n = data.data as number[]
          this.progress = n[2]
          this.speed = n[0]
          if (isMovingPhotoVideo) {
            item.updateUploadedSize(this.preSize + n[1])
          } else {
            item.updateUploadedSize(n[1])
            this.preSize = n[1]
          }
          if(n[2] == 100 && n[0] == 0) {
            console.log(`线程${this.index}: ${item.id} => ${item.remoteUri}进度100%`)
          }
          return
        }
        if (data.code === 1) {
          // 上传出错
          item.failed(data.message)
          resolve(false)
        }
      }
    })
  }

  build() {
    Column() {
      if (!this.isFinish) {
        Flex({
          direction: FlexDirection.Row,
          wrap: FlexWrap.NoWrap,
          justifyContent: FlexAlign.SpaceBetween,
          alignItems: ItemAlign.Center
        }) {
          Column() {
            Column() {
              Text("备份线程 " + this.index)
                .fontSize(12)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Flex({
              direction: FlexDirection.Row,
              wrap: FlexWrap.NoWrap,
              justifyContent: FlexAlign.SpaceBetween,
              alignItems: ItemAlign.Center
            }) {
              Text(`${this.fileName}(${formatFileSize(this.fileSize)})`)
                .fontSize(14)
              Text(`${formatFileSize(this.speed)}/秒`)
                .margin({ right: $r('app.float.inner_padding') })
                .fontSize(14)
            }
            .width('100%')

            Column() {
              IBestProgress({
                value: this.progress
              })
                .width('100%')
                .padding({ left: $r("app.float.normal_padding") })
            }
          }
          .layoutWeight(1)
        }
        .padding($r('app.float.normal_padding'))
        .backgroundColor($r("app.color.ibest_search_inner_background"))
        .borderRadius(10)
        .shadow({
          radius: 8,
          color: Color.Gray,
          offsetX: 10,
          offsetY: 10
        })
      } else {
        Column() {
          IBestIcon({ name: 'success', iconSize: 20 })
          Text("备份已完成")
        }
        .alignItems(HorizontalAlign.Center)
        .width('100%')
      }
    }
    .backgroundColor($r('app.color.ibest_background'))
    .width('100%')
    .padding($r("app.float.normal_padding"))
  }
}