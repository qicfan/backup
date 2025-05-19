import { TaskItem } from "../models/TaskItem";
import {
  AUTOBackup,
  ConfigGlobalStatus, LoginStatus, TaskDoing } from "../typing";
import { WorkerPool } from "./workerPool";
import { BusinessError, emitter } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";
import { WebDav } from "./webdav";
import { IBestNotify, IBestToast } from "@ibestservices/ibest-ui-v2";
import { checkBattery, checkWifi } from "./tools";
import { Config } from "../models/Config";
import { checkPermissions } from "./permission";
import { common, Context } from "@kit.AbilityKit";

export class TaskUpload {
  uploadWorkerPool: WorkerPool = new WorkerPool("entry/ets/workers/TaskWorker.ets")

  private static _instance: TaskUpload | null = null;
  private _webdav: WebDav | null = null;
  private _config: Config | null = null;
  private _global: Global | null = null;

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
    if (this.global.configGlobalStatus !== ConfigGlobalStatus.YES) {
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

  async start(ctx: Context, preTotal: number) {
    if (this.global.processId > 0) return false;
    if (!(await this.canStart())) return false;
    console.log(`taskUpload 任务开始执行...`)
    this.global.processId = 1;
    this.global.preTotal = preTotal;
    emitter.once(Global.STOP_TASK_EVENT, () => this.stop());
    this.uploadWorkerPool.execute(ctx, preTotal);
    return true;
  }

  async stop() {
    console.log(`主线程收到暂停消息`)
    this.global.processId = 0;
    // 终止所有上传线程
    this.uploadWorkerPool.stop();
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
    if (this.global.processId > 0) {
      console.warn(`正在执行备份，无法启动收集任务`);
      return false;
    }
    // 如果正在创建备份任务
    if (this.global.taskGlobalStatus === TaskDoing.YES) {
      console.warn(`无法启动收集带备份任务，有运行中的创建任务`);
      return false;
    }
    // 检查是否授权读取相册
    if (!(await this.checkPerm())) {
      console.warn(`无法启动收集带备份任务，未授权`);
      return false;
    }
    if (this.global.loginStatus !== LoginStatus.LOGIN) {
      console.warn(`服务器无法登录，无法启动创建任务`);
      return false;
    }
    if (this.global.configGlobalStatus !== ConfigGlobalStatus.YES) {
      console.warn(`没有设置备份路径，无法启动创建任务`);
      return false;
    }
    return true;
  }

  async startCreateTask(ctx: Context): Promise<boolean> {
    console.log(`数据库路径：${ctx.databaseDir}，缓存路径：${ctx.cacheDir}`)
    if (!(await this.canCreateTask())) {
      return false;
    }
    console.log(`开始创建TaskItems`);
    this.global.taskGlobalStatus = TaskDoing.YES;
    let exists: boolean = false;
    try {
      exists = await TaskItem.createTask(ctx, this.config);
      this.global.taskGlobalStatus = TaskDoing.NO;
      emitter.emit(Global.COLLECT_PHOTO_FINISH_EVENT, { data: { exists: exists } });
    } catch (e) {
      let err = e as BusinessError;
      console.error(`创建TaskItems失败: code=${err.code}, msg=${err.message}`)
    } finally {
      if (this.config.auto === AUTOBackup.YES) {
        // 触发任务执行
        this.start(ctx, TaskItem.getWaitCount());
      }
    }
    return exists;
  }
}