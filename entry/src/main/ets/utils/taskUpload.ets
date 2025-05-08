import { Queue } from "@kit.ArkTS";
import { TaskItem } from "../models/TaskItem";
import { UploadItemSendable } from "../models/UploadItemSendable";
import { LowBatteryStop, OnlyWIFIBackup, UploadQueueItem } from "../typing";
import { WorkerPool } from "./workerPool";
import { emitter } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { relationalStore } from "@kit.ArkData";
import { Task } from "../models/Task";
import { WebDav } from "./webdav";
import { IBestNotify } from "@ibestservices/ibest-ui-v2";
import { getBatteryLevel, getCurrentNetType } from "./tools";
import { Config } from "../models/Config";
import { connection } from "@kit.NetworkKit";

export class TaskUpload {
  uploadItemQueue: Queue<UploadQueueItem> = new Queue<UploadQueueItem>();
  copyImageQueue: Queue<TaskItem> = new Queue<TaskItem>();
  fileWorkerPool: WorkerPool = new WorkerPool("entry/ets/workers/CopyImageWorker.ets")
  uploadWorkerPool: WorkerPool = new WorkerPool("entry/ets/workers/UploadWorker.ets")

  private static _instance: TaskUpload | null = null;
  private _webdav: WebDav | null = null;
  private _config: Config | null = null;

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

  checkBattery() {
    if (this.config.lowBatteryStop === LowBatteryStop.YES) {
      if (getBatteryLevel() <= 15) {
        IBestNotify.show({
          message: "已打开低电量不备份，当前电量低于15%，不启动备份任务",
          type: "warning",
          duration: 3000
        })
        return false;
      }
    }
    return true;
  }

  async checkWifi() {
    if (this.config.onlyWifi === OnlyWIFIBackup.YES) {
      const netType = await getCurrentNetType();
      if (netType == connection.NetBearType.BEARER_CELLULAR) {
        IBestNotify.show({
          message: "已打开仅wifi备份，当前使用移动网络，不启动备份任务",
          type: "warning",
          duration: 3000
        })
        return false;
      }
    }
    return true;
  }

  async start(context: Context, task: Task) {
    if (!this.checkBattery()) {
      console.warn(`开启了低电量停止备份，检测到当前电量低于15%，无法启动备份`)
      return;
    }
    if(!(await this.checkWifi())) {
      console.warn(`开启了仅WIFI备份，检测到当前处于非WIFI网络，无法启动备份`)
      return;
    }
    console.info("开始上传照片");
    // 将任务标记为开始执行
    await task.start();
    console.log(`任务 ${task.id} 开始执行...`)
    const auth = this.webdav.getBase64Auth();
    // 复制队列出现空闲线程
    emitter.on(Global.BACKUP_COPY_WORKER_IDLE, async () => {
      if (!this.checkBattery()) {
        console.warn(`开启了低电量停止备份，检测到当前电量低于15%，无法启动备份`)
        emitter.emit(Global.BACKUP_PAUSE)
        return;
      }
      if(!(await this.checkWifi())) {
        console.warn(`开启了仅WIFI备份，检测到当前处于非WIFI网络，无法启动备份`);
        emitter.emit(Global.BACKUP_PAUSE)
        return;
      }
      if (this.copyImageQueue.length === 0) {
        console.log(`复制队列已空`);
        return ;
      }
      console.log(`复制队列剩余：${this.copyImageQueue.length}`)
      const taskItem: TaskItem = this.copyImageQueue.pop();
      const isSuc: boolean = this.fileWorkerPool.executeCopyImage(taskItem);
      if (!isSuc) {
        // 进入执行队列失败，再放回队列
        this.copyImageQueue.add(taskItem);
      }
    })
    // 上传队列出现空闲线程
    emitter.on(Global.BACKUP_UPLOAD_WORKER_IDLE, async () => {
      if (!this.checkBattery()) {
        console.warn(`开启了低电量停止备份，检测到当前电量低于15%，无法启动备份`)
        emitter.emit(Global.BACKUP_PAUSE)
        return;
      }
      if(!(await this.checkWifi())) {
        console.warn(`开启了仅WIFI备份，检测到当前处于非WIFI网络，无法启动备份`);
        emitter.emit(Global.BACKUP_PAUSE)
        return;
      }
      if (this.uploadItemQueue.length === 0) {
        console.log(`上传队列已空`);
        if (this.copyImageQueue.length === 0) {
          // 上传和复制队列都空，检查是否有正在运行的线程
          const idleCopyCount = this.fileWorkerPool.idleCopyCount();
          const idleUploadCount = this.uploadWorkerPool.idleUploadCount();
          console.log(`复制和上传队列都空，空闲线程： copy=${idleCopyCount}, upload=${idleUploadCount}`)
          if (idleCopyCount == this.fileWorkerPool.current && idleUploadCount === this.uploadWorkerPool.current) {
            console.log(`已经没有任何活跃线程，任务已经结束。`)
            // 终止所有复制线程
            this.fileWorkerPool.clear();
            // 终止所有上传线程
            this.uploadWorkerPool.clear();
            // 如果线程全部空闲，则代表任务已经结束
            emitter.emit(Global.BACKUP_TASK_FINISH, {data: {taskId: task.id}});
          }
        }
        return ;
      }
      console.log(`上传队列剩余：${this.copyImageQueue.length}`)
      const uploadQueueItem: UploadQueueItem = this.uploadItemQueue.pop();
      const uploadItem = uploadQueueItem.uploadItem;
      const taskItem = uploadQueueItem.taskItem;
      const curTask = await Task.getById(taskItem.taskId);
      if (!curTask) {
        console.log(`上传队列查询task不存在，${taskItem.taskId}`);
        return;
      }
      const isSuc: boolean = this.uploadWorkerPool.execute(uploadItem, curTask, taskItem);
      if (!isSuc) {
        console.log(`没有空闲的上传线程，放回上传队列`)
        this.uploadItemQueue.add(uploadQueueItem);
      }
    })
    // 复制文件完成的消息，加入上传队列
    emitter.on(Global.BACKUP_COPY_FINISH, async (data) => {
      const taskItemId: number = data.data?.taskItemId;
      console.log(`收到复制完成消息，将该任务放入上传队列2，${taskItemId}`)
      const taskItem = await TaskItem.getById(taskItemId);
      if (!taskItem) return;
      const curTask = await Task.getById(taskItem.taskId);
      if (!curTask) return;
      const uploadItem = new UploadItemSendable(context, taskItem, auth);
      // 触发执行
      const rs = this.uploadWorkerPool.execute(uploadItem, curTask, taskItem);
      if (!rs) {
        console.log(`没有空闲的上传线性，将复制完成的任务放回上传队列`)
        this.uploadItemQueue.add({uploadItem: uploadItem, taskItem: taskItem});
      }
      if (taskItem.subType === photoAccessHelper.PhotoSubtype.MOVING_PHOTO) {
        console.log(`将动态图的视频放入上传队列`)
        const uploadItem = new UploadItemSendable(context, taskItem, auth, 2);
        // 触发执行
        const rs = this.uploadWorkerPool.execute(uploadItem, curTask, taskItem);
        if (!rs) {
          console.log(`没有空闲的上传线性，将复制完成的动态图的视频放回上传队列`)
          this.uploadItemQueue.add({uploadItem: uploadItem, taskItem: taskItem});
        }
      }
    })
    let pause: boolean = false;
    // 处理暂停事件
    emitter.on(Global.BACKUP_PAUSE, (data) => {
      pause = true;
      // 终止所有复制线程
      this.fileWorkerPool.clear();
      // 终止所有上传线程
      this.uploadWorkerPool.clear();
      // 任务定义未失败
      // task.finish(data.data?.reason)
      // 清空队列
      while(true) {
        if (this.copyImageQueue.length === 0) {
          break;
        } else {
          this.copyImageQueue.pop();
        }
      }
      while(true) {
        if (this.uploadItemQueue.length === 0) {
          break;
        } else {
          this.uploadItemQueue.pop();
        }
      }
    })
    let page = 1;
    let pageSize = 1000;
    while (true) {
      if (pause) break;
      await task.fetch()
      const rs: relationalStore.ResultSet | null = await task.getWaitItems(page, pageSize)
      let count: number = 0;
      if (rs !== null) count = rs.rowCount;
      console.log(`第${page}页查询到${count}条数据`)
      if (count === 0) break;
      while (rs?.goToNextRow()) {
        const taskItem = TaskItem.getInstance(rs);
        taskItem.task = task;
        // 加入文件复制队列
        this.copyImageQueue.add(taskItem);
      }
      rs?.close();
      if (count === pageSize) {
        page++;
      } else {
        break;
      }
    }
    // 触发任务执行
    let taskItem: TaskItem;
    if (this.copyImageQueue.length > 0) {
      taskItem = this.copyImageQueue.pop();
      const isAddSuc: boolean = this.fileWorkerPool.executeCopyImage(taskItem);
      if (!isAddSuc) {
        this.copyImageQueue.add(taskItem);
      }
    }
  }
}