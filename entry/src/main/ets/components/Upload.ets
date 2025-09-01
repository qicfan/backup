import { IBestLoading, IBestNotify } from "@ibestservices/ibest-ui-v2";
import { AppStorageV2 } from "@kit.ArkUI";
import { Config } from "../models/Config";
import { ServerConfig } from "../models/Server";
import { TaskItem } from "../models/TaskItem";
import { BackupServer } from "../utils/server";
import { UploadQueue } from "../utils/UploadQueue";
import { UploadItem } from "./UploadItem";
import { emitter } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";

@ComponentV2
export struct Upload {
  @Local config: Config = AppStorageV2.connect(Config, "config", () => Config.getInstance())!;
  @Local backupServer: BackupServer = AppStorageV2.connect(BackupServer, "BackupServer", () => BackupServer.getInstance())!;
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => ServerConfig.getInstance())!;
  @Local maxThreadCount: number[] = Array.from<number, number>({length: 5}, (_, index) => index + 1)
  @Local uploadQueue: UploadQueue = AppStorageV2.connect(UploadQueue, "UploadQueue", () => UploadQueue.getInstance())!;
  @Local already: boolean = false
  @Local isEnd: boolean = false // 是否已经无法从数据库中获取到数据（备份线程可以结束）
  private page = 0
  private pageSize  = 100
  private ctx: Context = getContext(this)
  private SI: number = 0
  private finishIdx: number[] = []
  private existsIds: number[] = []
  aboutToAppear(): void {
    // 读取待备份的数据
    // 循环将初始数据加入队列，100条
    // 每隔100毫秒检查队列数量，如果少于100条责加入直到100条；如果剩余待备份数量为0则停止检查
    this.finishIdx = []
    this.existsIds = []
    let total = Global.getInstance().preTotal
    if (total < this.maxThreadCount.length) {
      this.maxThreadCount = Array.from<number, number>({length: total}, (_, index) => index + 1)
    }
    this.initUpload()
    emitter.once(Global.STOP_TASK_EVENT, () => {
      if (this.SI > 0) {
        clearInterval(this.SI)
        this.SI = 0
      }
    })
  }

  aboutToDisappear(): void {
    this.uploadQueue.clear()
    if (this.SI > 0) {
      clearInterval(this.SI)
      this.SI = 0
    }
  }

  initUpload() {
    console.log('开始初始化上传数据')
    let isStop: boolean = false
    let getDataLock: boolean = false
    this.SI = setInterval(() => {
      if (isStop) {
        console.log('收到停止信号')
        clearInterval(this.SI)
        this.SI = 0
        return
      }
      if (getDataLock) {
        // console.log('正在将待备份列表添加到队列，跳过本次检查')
        return
      }
      // console.log(`上传队列长度： ${this.uploadQueue.length()}`)
      if (this.uploadQueue.length() <= 10) {
        this.page ++
        getDataLock = true
        this.getData().then((rs: number) => {
          if (this.page === 1) {
            console.log('首次完成getData，生成工作线程并开始备份')
            this.already = true
          }
          if (rs === 1) {
            isStop = true
          }
          getDataLock = false
        })
      } else {
        // console.log('队列长度：' + this.uploadQueue.length() + ", 跳过本次检查，等待队列被上传")
      }
    }, 10)
    // console.log('完成初始化上传数据方法的调用')
  }

  async getData() {
    // console.log(`开始查询待备份列表 ${this.page} : ${this.pageSize}`)
    let items = await TaskItem.getUploadList(this.ctx, this.pageSize)
    // console.log(`查询到 ${items.length} 条`)
    if (items.length === 0) {
      console.log(`无法查询到待备份列表`)
      this.isEnd = true
      clearInterval(this.SI)
      return 1
    }
    items.forEach((item: TaskItem) => {
      if (this.existsIds.includes(item.id)) {
        console.log(`${item.id} 已经在队列中，队列长度：${this.uploadQueue.length()}`)
        return
      }
      this.existsIds.push(item.id)
      // 检查ID是否已经进入队列
      this.uploadQueue.add(item)
      // console.log(`${item.id}已加入队列，队列长度：${this.uploadQueue.length()}`)
    })
    return 0
  }

  threadFinish(idx: number) {
    console.log(`线程 ${idx} 已完成备份`)
    if (this.finishIdx.includes(idx)) {
      return
    }
    this.finishIdx.push(idx)
    if (this.finishIdx.length == this.maxThreadCount.length) {
      console.log(`所有线程 ${JSON.stringify(this.finishIdx)} 已完成备份，线程数量：${this.maxThreadCount.length}`)
      // 所有线程全部完成，表示上传已完成
      IBestNotify.show({
        message: '本次备份已完成。',
        duration: 3000,
        type: 'success'
      })
      emitter.emit(Global.STOP_TASK_EVENT)
    }
  }

  build() {
    Column() {
      if (this.already) {
        ForEach(this.maxThreadCount, (item: number) => {
          UploadItem({index: item, isEnd: this.isEnd, finish: (idx: number) => {this.threadFinish(idx)}})
        }, (item: number) => item + "")
      } else {
        Column() {
          IBestLoading({
            loadingText: "正在准备上传的数据..."
          })
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ibest_background'))
  }
}