import { TaskItem } from "../models/TaskItem";
import { UploadItemSendable } from "../models/UploadItemSendable";
import {
  AUTOBackup,
  ConfigGlobalStatus, LoginStatus, LowBatteryStop, OnlyWIFIBackup, TaskDoing, UploadQueueItem } from "../typing";
import { WorkerPool } from "./workerPool";
import { BusinessError, emitter } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { WebDav } from "./webdav";
import { IBestNotify, IBestToast } from "@ibestservices/ibest-ui-v2";
import { checkBattery, checkWifi, getBatteryLevel, getCurrentNetType } from "./tools";
import { Config } from "../models/Config";
import { connection } from "@kit.NetworkKit";
import { TaskItemQueue } from "../common/TaskItemQueue";
import { checkPermissions } from "./permission";
import { common, UIAbility } from "@kit.AbilityKit";

export class TaskUpload {
  taskItemQueue: TaskItemQueue = TaskItemQueue.getInstance();
  fileWorkerPool: WorkerPool = new WorkerPool("entry/ets/workers/CopyImageWorker.ets")
  uploadWorkerPool: WorkerPool = new WorkerPool("entry/ets/workers/UploadWorker.ets")

  private static _instance: TaskUpload | null = null;
  private _webdav: WebDav | null = null;
  private _config: Config | null = null;
  private _global: Global | null = null;

  private backupUploadIdleCallback: Callback<emitter.EventData> = (eventData: emitter.EventData) => {
    this.backupUploadIdle();
  }

  private backupCopyFinishCallback: Callback<emitter.EventData> = (eventData: emitter.EventData) => {
    this.backupCopyFinish();
  }

  static getInstance() {
    if (TaskUpload._instance === null) {
      TaskUpload._instance = new TaskUpload();
    }
    return TaskUpload._instance;
  }

  get webdav() {
    if (this._webdav === null) {
      this._webdav = WebDav.getInstance();
    }
    return this._webdav;
  }

  get config() {
    if (this._config === null) {
      this._config = Config.getInstance();
    }
    return this._config;
  }

  get global() {
    if (this._global === null) {
      this._global = Global.getInstance();
    }
    return this._global;
  }

  // 是否开源启动任务执行
  async canStart(): Promise<boolean> {
    // 如果打开了低电量暂停任务，则检查电量
    if (!checkBattery(this.config)) {
      IBestToast.show({
        message: "您开启了低电量停止备份，当前电量不足15%，无法启动备份",
        type: "warning",
        duration: 3000
      })
      return false;
    }
    // 如果打开了仅WIFI备份，则检查网络状态
    if (!(await checkWifi(this.config))) {
      IBestToast.show({
        message: "您开启了仅WIFI备份，但是当前没有连接WIFI，无法启动备份",
        type: "warning",
        duration: 3000
      })
      return false;
    }
    if (!this.config.backupRootPath) {
      IBestToast.show({
        message: "请先设置备份路径",
        type: "warning",
        duration: 3000
      })
      return false;
    }
    const rr = await this.webdav.valid();
    if (!rr.success) {
      IBestToast.show({
        message: "服务器不可用，请检查当前设备的网络环境或者连接状态",
        type: "warning",
        duration: 3000
      })
      return false;
    }
    return true;
  }

  async backupUploadIdle() {
    console.log('主线程收到上传完成消息')
    if (!checkBattery(this.config)) {
      console.warn(`开启了低电量停止备份，检测到当前电量低于15%，无法启动备份`)
      this.stop().then();
      return;
    }
    if(!(await checkWifi(this.config))) {
      console.warn(`开启了仅WIFI备份，检测到当前处于非WIFI网络，无法启动备份`);
      this.stop().then()
      return;
    }
    if (this.taskItemQueue.uploadItemQueue.length > 0 || this.taskItemQueue.copyImageQueue.length > 0) return ;
    // 上传和复制队列都空，检查是否有正在运行的线程
    const idleCopyCount = this.fileWorkerPool.idleCopyCount();
    const idleUploadCount = this.uploadWorkerPool.idleUploadCount();
    console.log(`复制和上传队列都空，空闲线程： copy=${idleCopyCount}/${this.fileWorkerPool.copyCurrent}, upload=${idleUploadCount}/${this.uploadWorkerPool.current}`)
    if (idleCopyCount == this.fileWorkerPool.copyCurrent && idleUploadCount === this.uploadWorkerPool.current) {
      console.log(`已经没有任何活跃线程，任务已经结束。`)
      // 终止所有复制线程
      this.fileWorkerPool.clear();
      // 终止所有上传线程
      this.uploadWorkerPool.clear();
      this.global.processId = 0;
      // 如果线程全部空闲，则代表任务已经结束
      emitter.emit(Global.BACKUP_TASK_FINISH);
    }
  }
  async backupCopyFinish() {
    console.log('主线程收到复制完成消息2')
    // 检查上传线程池是否已满，如果未满则新建上传线程
    if (this.uploadWorkerPool.current >= this.uploadWorkerPool.max) {
      console.warn(`4主线程创建上传线程失败：uploadCurrent=${this.uploadWorkerPool.current}, uploadMax=${this.uploadWorkerPool.max}`)
      return;
    }
    console.log(`上传线程未满，触发新建上传线程并执行3`)
    const uploadQueueItem: UploadQueueItem = this.taskItemQueue.uploadItemQueue.pop();
    if (!uploadQueueItem) return ;
    const uploadItem = uploadQueueItem.uploadItem;
    const taskItem = uploadQueueItem.taskItem;
    const isSuc: boolean = this.uploadWorkerPool.execute(uploadItem, taskItem);
    if (!isSuc) {
      console.log(`没有空闲的上传线程，放回上传队列`);
      this.taskItemQueue.uploadItemQueue.add(uploadQueueItem);
    }
  }

  async start() {
    if (this.global.processId > 0) return false;
    if (!(await this.canStart())) return false;
    console.log(`taskUpload 任务开始执行...`)
    this.global.processId = 1;
    // 上传完成的消息，检测任务是否已经完成;
    emitter.on(Global.BACKUP_UPLOAD_WORKER_IDLE, this.backupUploadIdleCallback);
    // 复制文件完成的消息，触发上传队列开始运行
    emitter.on(Global.BACKUP_COPY_FINISH, this.backupCopyFinishCallback);
    emitter.once(Global.STOP_TASK_EVENT, () => this.stop());
    let page = 1;
    let pageSize = 1000;
    while (true) {
      if (this.global.processId === 0) break;
      const items: TaskItem[] = await TaskItem.getWaitList(page, pageSize)
      let count: number = items.length;
      console.log(`第${page}页查询到${count}条数据`)
      if (count === 0) break;
      for (let i=0; i<count; i++) {
        const taskItem = items[i];
        if (!taskItem) continue;
        // 加入文件复制队列
        this.taskItemQueue.copyImageQueue.add(taskItem);
      }
      if (count === pageSize) {
        page++;
      } else {
        break;
      }
    }
    // 触发任务执行
    let taskItem: TaskItem;
    if (this.taskItemQueue.copyImageQueue.length > 0) {
      taskItem = this.taskItemQueue.copyImageQueue.pop();
      const isAddSuc: boolean = this.fileWorkerPool.executeCopyImage(taskItem);
      if (!isAddSuc) {
        this.taskItemQueue.copyImageQueue.add(taskItem);
      }
    }
    return true;
  }

  async stop() {
    console.log(`主线程收到暂停消息`)
    this.global.processId = 0;
    // 终止所有复制线程
    this.fileWorkerPool.stop();
    // 终止所有上传线程
    this.uploadWorkerPool.stop();
    // 清空队列
    while(true) {
      if (this.taskItemQueue.copyImageQueue.length === 0) {
        break;
      } else {
        const taskItem: TaskItem = this.taskItemQueue.copyImageQueue.pop();
        taskItem.wait().then(() => {
          emitter.emit(Global.UPDATE_TASK_ITEM_EVENT + '_' + taskItem.id, {data: {id: taskItem.id}})
        })
      }
    }
    while(true) {
      if (this.taskItemQueue.uploadItemQueue.length === 0) {
        break;
      } else {
        const item = this.taskItemQueue.uploadItemQueue.pop();
        item.taskItem.wait().then(() => {
          emitter.emit(Global.UPDATE_TASK_ITEM_EVENT + '_' + item.taskItem.id, {data: {id: item.taskItem.id}})
        })
      }
    }
    // 所有UPLOADING 改为 WAIT
    TaskItem.uploadingToWait().then(() => {})
    // 取消订阅事件
    emitter.off(Global.BACKUP_UPLOAD_WORKER_IDLE, this.backupUploadIdleCallback);
    // 复制文件完成的消息，触发上传队列开始运行
    emitter.off(Global.BACKUP_COPY_FINISH, this.backupCopyFinishCallback);
    emitter.emit(Global.STOP_BACKGROUND_EVENT);
  }


  checkPerm(): Promise<boolean> {
    return new Promise((resolve) => {
      checkPermissions(getContext() as common.UIAbilityContext, 'ohos.permission.READ_IMAGEVIDEO').then((rs) => {
        if (rs) {
          resolve(true)
        } else {
          IBestNotify.show({
            message: "未授权访问相册，请到'设置 > 应用和元服务 > 相册备份'中打开'图片和视频 -> 仅读取'权限后再重新打开本应用",
            type: "warning",
            duration: 3000
          })
          resolve(false);
        }
      })
    })
  }

  // 是否开源收集照片并生成任务
  async canCreateTask(): Promise<boolean> {
    if (this.global.loginStatus !== LoginStatus.LOGIN || this.global.configGlobalStatus !== ConfigGlobalStatus.YES) {
      console.warn(`服务器无法登录或者没有设置备份路径，无法启动创建任务`);
      return false;
    }
    // 检查是否授权读取相册
    if (!(await this.checkPerm())) {
      console.warn(`无法启动收集带备份任务，未授权`);
      return false;
    }
    // 如果正在创建备份任务
    if (this.global.taskGlobalStatus === TaskDoing.YES) {
      console.warn(`无法启动收集带备份任务，有运行中的创建任务`);
      return false;
    }
    if (this.global.processId > 0) {
      console.warn(`正在执行备份，无法启动收集任务`);
    }
    return true;
  }

  async startCreateTask(ctx: Context): Promise<boolean> {
    if (!(await this.canCreateTask())) {
      return false;
    }
    console.log(`开始创建TaskItems`);
    this.global.taskGlobalStatus = TaskDoing.YES;
    let exists: boolean = false;
    try {
      exists = await TaskItem.createTask(ctx, this.config)
    } catch (e) {
      let err = e as BusinessError;
      console.error(`创建TaskItems失败: code=${err.code}, msg=${err.message}`)
    } finally {
      setTimeout(() => {
        if (this.config.auto === AUTOBackup.YES) {
          // 触发任务执行
          this.start();
        }
      }, 1000)
    }
    this.global.taskGlobalStatus = TaskDoing.NO;
    emitter.emit(Global.COLLECT_PHOTO_FINISH_EVENT, { data: { exists: exists } })
    return exists;
  }
}