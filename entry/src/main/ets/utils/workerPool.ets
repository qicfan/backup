import { ErrorEvent, MessageEvents, worker } from "@kit.ArkTS";
import { UploadItemSendable } from "../models/UploadItemSendable";
import { emitter } from "@kit.BasicServicesKit";
import { CopyWorkerMessage, TaskItemStatus, WorkerMessage } from "../typing";
import { Task } from "../models/Task";
import { TaskItem } from "../models/TaskItem";
import { Global } from "../models/Global";
import { CopyItemSendable } from "../models/CopyItemSendable";

// 上传工作线程
export class UploadWorkerItem {
  isIdle: boolean = true; // 是否空闲
  workerInstance: worker.ThreadWorker | undefined = undefined; // 工作线程实例
  uploadItem: UploadItemSendable | undefined = undefined; // 待上传对象
  task: Task | undefined = undefined;
  taskItem: TaskItem | undefined = undefined;

  init(workerInstance: worker.ThreadWorker) {
    this.workerInstance = workerInstance;
    workerInstance.onmessage = (e: MessageEvents): void => {
      // data：worker线程发送的信息
      console.log(`收到上传回调消息，结果：${JSON.stringify(e.data)}`)
      let data: WorkerMessage = e.data;
      if (this.uploadItem === undefined) {
        this.isIdle = true;
        return;
      }
      const taskItemId = data.taskItemId;
      const taskItem = new TaskItem();
      taskItem.id = taskItemId;
      taskItem.fetch().then(() => {
        const task = new Task();
        task.id = taskItem.taskId;
        task.fetch().then(async () => {
          if (data.action === "UPDATE_PROGRESS") {
            await taskItem.updateUploadedSize(data.uploadedSize ? data.uploadedSize : 0);
            return ;
          }
          if (data.action === "FINISH") {
            if (data.type === 2) {
              await taskItem.updateUploadedSize(taskItem.size + taskItem.videoSize).then();
            } else {
              await taskItem.updateUploadedSize(taskItem.size);
            }
            await taskItem.success()
            console.log(`文件${taskItem.id} 已完成，状态: ${taskItem.status}, 已上传：${taskItem.uploadedSize}`)
            const rs: boolean = await task?.canFinish()
            console.log(`任务${task.id} 已检查是否完成，状态: ${task.status},成功：${task.success}, 失败:${task.failed}, 已上传字节数：${task.realUploadedSize}，总字节数：${task.size}`)
            // 通知主线程有任务空闲
            this.resetProp();
            emitter.emit(Global.BACKUP_UPLOAD_WORKER_IDLE);
            if (rs) {
              emitter.emit(Global.BACKUP_TASK_FINISH, {data: {taskId: task.id}})
            }
            return ;
          }
          if (data.action === "ERROR") {
            console.error(JSON.stringify(data));
            // 上传发生错误
            await taskItem.failed(data.message);
            await task.canFinish()
            this.resetProp();
            // 通知主线程有任务空闲
            emitter.emit(Global.BACKUP_UPLOAD_WORKER_IDLE)
          } else {
            this.resetProp();
            // 通知主线程有任务空闲
            emitter.emit(Global.BACKUP_UPLOAD_WORKER_IDLE)
          }
        })
      })
    }
    // 在调用terminate后，执行回调onexit
    workerInstance.onexit = async () => {
      console.log("main thread terminate");
      // 如果任务不是完成，则将任务改为未开始
      // await this.task?.fetch();
      // await this.taskItem?.fetch();
      // if (this.taskItem?.status !== TaskItemStatus.SUCCESS) {
      //   await this.taskItem?.failed("任务被暂停");
      // }
    }
    workerInstance.onerror = (err: ErrorEvent) => {
      console.error("main error message " + err.message);
      this.resetProp();
      // 通知主线程有任务空闲
      emitter.emit(Global.BACKUP_UPLOAD_WORKER_IDLE)
    }
  }

  async execute(uploadItem: UploadItemSendable, task: Task, taskItem: TaskItem) {
    this.uploadItem = uploadItem;
    this.isIdle = false;
    this.task = task;
    this.taskItem = taskItem;
    await this.task.start();
    await this.taskItem.start();
    this.workerInstance?.postMessageWithSharedSendable(this.uploadItem);
  }

  destroy() {
    this.workerInstance?.terminate();
    this.workerInstance = undefined;
    this.resetProp();
  }

  resetProp() {
    this.isIdle = true;
    this.uploadItem = undefined;
    this.task = undefined;
    this.taskItem = undefined;
  }
}

// 复制文件工作线程
export class CopyImageWorkItem {
  isIdle: boolean = true; // 是否空闲
  workerInstance: worker.ThreadWorker | undefined = undefined; // 工作线程实例
  taskItem: TaskItem | undefined = undefined;

  init(workerInstance: worker.ThreadWorker) {
    this.workerInstance = workerInstance;
    workerInstance.onmessage = (e: MessageEvents): void => {
      const copyWorkMsg: CopyWorkerMessage = e.data;
      console.log(`收到复制文件回调消息，结果：${JSON.stringify(copyWorkMsg)}`)
      if (e.data) {
        // 更新视频文件大小
        const taskItemId: number = copyWorkMsg.taskItemId;
        const taskItem = new TaskItem();
        taskItem.id = taskItemId;
        taskItem.fetch().then(() => {
          // 更新文件大小
          if (copyWorkMsg.imageSize != taskItem.size || copyWorkMsg.videoSize != this.taskItem?.videoSize) {
            console.log(`更新文件大小${taskItem.id} => size: ${copyWorkMsg.imageSize}, videoSize: ${copyWorkMsg.videoSize}`)
            taskItem.updateSize(copyWorkMsg.imageSize, copyWorkMsg.videoSize).then(() => {
              this.resetProp();
              emitter.emit(Global.BACKUP_COPY_FINISH, {data: {taskItemId: copyWorkMsg.taskItemId}})
              emitter.emit(Global.BACKUP_COPY_WORKER_IDLE)
            })
          } else {
            this.resetProp();
            emitter.emit(Global.BACKUP_COPY_FINISH, {data: {taskItemId: copyWorkMsg.taskItemId}});
            emitter.emit(Global.BACKUP_COPY_WORKER_IDLE)
          }
        })
      }
    }
    // 在调用terminate后，执行回调onexit
    workerInstance.onexit = () => {

    }
    workerInstance.onerror = (err: ErrorEvent) => {
      console.log("main error message " + err.message);
    }
  }

  async execute(taskItem: TaskItem) {
    this.isIdle = false;
    this.taskItem = taskItem;
    await this.taskItem.start();
    const copyItem = new CopyItemSendable(getContext(), taskItem);
    this.workerInstance?.postMessageWithSharedSendable(copyItem);
  }

  destroy() {
    this.workerInstance?.terminate();
    this.workerInstance = undefined;
    this.resetProp();
  }

  resetProp() {
    this.isIdle = true;
    this.taskItem = undefined;
  }
}

// worker池
export class WorkerPool {
  max: number = 10; // 最大进程数
  min: number = 0; // 最小进程数
  current: number = 0; // 当前进程数
  copyCurrent: number = 0; // 当前进程数
  workerFileUri: string = ""; // worker路径
  workerItems: Array<UploadWorkerItem> = [];
  copyWorkerItems: Array<CopyImageWorkItem> = [];
  type: number = 1;

  constructor(workerFileUri: string, max: number = 10, min: number = 0) {
    this.workerFileUri = workerFileUri;
    this.max = max;
    this.min = min;
  }

  executeCopyImage(taskItem: TaskItem): boolean {
    let isDist: boolean = false;
    for (let i=0; i<this.copyWorkerItems.length; i ++) {
      const item = this.copyWorkerItems[i];
      if (item.isIdle) {
        // console.log(`有空闲线程，执行taskItem: ${taskItem.id}`)
        item.execute(taskItem)
        isDist = true;
        break;
      }
    }
    if (isDist) {
      this.checkCopyIdle();
      return true;
    }
    if (this.copyCurrent < this.max) {
      // 创建一个新线程
      const copyWorkerItem = this.newCopyItem();
      copyWorkerItem.execute(taskItem);
      this.checkCopyIdle();
      return true;
    }
    return false;
  }
  /**
   * 执行线程池，给任务分配空闲进程
   * 1. 轮询当前线程是否有空闲
   * 2. 发现空闲线程则执行
   * 3. 如果没有空闲线程，则创建线程（如果current < max)
  */
  execute(uploadItem: UploadItemSendable, task: Task, taskItem: TaskItem) {
    let isDist: boolean = false;
    for (let i=0; i<this.workerItems.length; i ++) {
      const item = this.workerItems[i];
      if (item.isIdle) {
        console.log(`有空闲线程，执行上传taskItem: ${taskItem.id}`)
        item.execute(uploadItem, task, taskItem)
        isDist = true;
        break;
      }
    }
    if (isDist) {
      this.checkIdle();
      return true;
    }
    if (this.current < this.max) {
      // 创建一个新线程
      console.log(`新建线程，执行上传taskItem: ${taskItem.id}`)
      const workerItem = this.newItem();
      workerItem.execute(uploadItem, task, taskItem);
      this.checkIdle();
      return true;
    }
    return false;
  }

  checkIdle() {
    if (this.current < this.max) {
      console.log(`上传文件线程池没满，触发入栈`)
      emitter.emit(Global.BACKUP_UPLOAD_WORKER_IDLE)
    }
  }

  checkCopyIdle() {
    if (this.current < this.max) {
      // console.log(`复制文件线程池没满，触发入栈`)
      emitter.emit(Global.BACKUP_COPY_WORKER_IDLE)
    }
  }

  newItem(): UploadWorkerItem {
    const item = new UploadWorkerItem();
    item.init(new worker.ThreadWorker(this.workerFileUri));
    this.workerItems.push(item);
    this.current += 1;
    return item;
  }

  newCopyItem(): CopyImageWorkItem {
    const item = new CopyImageWorkItem();
    item.init(new worker.ThreadWorker(this.workerFileUri));
    this.copyWorkerItems.push(item);
    this.copyCurrent += 1;
    return item;
  }

  // 清除空闲线程，直到min
  clear() {
    if (this.type === 1) {
      const newItems: Array<UploadWorkerItem> = [];
      for (let i = 0; i < this.workerItems.length; i++) {
        const item = this.workerItems[i];
        if (!item.isIdle) {
          newItems.push(item);
          continue;
        }
        if (this.current > this.min) {
          item.destroy();
          this.current--;
          continue;
        }
        newItems.push(item);
      }
      this.workerItems = newItems;
    } else {
      const newItems: Array<CopyImageWorkItem> = [];
      for (let i = 0; i < this.copyWorkerItems.length; i++) {
        const item = this.copyWorkerItems[i];
        if (!item.isIdle) {
          newItems.push(item);
          continue;
        }
        if (this.copyCurrent > this.min) {
          item.destroy();
          this.copyCurrent--;
          continue;
        }
        newItems.push(item);
      }
      this.copyWorkerItems = newItems;
    }
  }

  // 空闲的复制线程数
  idleCopyCount() {
    let count: number = 0;
    for (let i=0; i<this.copyWorkerItems.length; i ++) {
      const item = this.copyWorkerItems[i];
      if (item.isIdle) count ++;
    }
    return count;
  }
  // 空闲的上传线程数
  idleUploadCount() {
    let count: number = 0;
    for (let i=0; i<this.workerItems.length; i ++) {
      const item = this.workerItems[i];
      if (item.isIdle) count ++;
    }
    return count;
  }

}