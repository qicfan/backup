import { ErrorEvent, MessageEvents, worker } from "@kit.ArkTS";
import { WorkerMessage } from "../typing";
import { TaskItemSendable } from "../models/TaskItemSendable";
import { common } from "@kit.AbilityKit";
import { emitter } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";

// 上传工作线程
export class UploadWorkerItem {
  isIdle: boolean = true; // 是否空闲
  workerInstance: worker.ThreadWorker | undefined = undefined; // 工作线程实例
  uploadItem: TaskItemSendable | undefined = undefined; // 待上传对象

  init(workerInstance: worker.ThreadWorker) {
    this.workerInstance = workerInstance;
    workerInstance.onmessage = (e: MessageEvents): void => {
      // data：worker线程发送的信息
      console.log(`收到上传回调消息，结果：${JSON.stringify(e.data)}`)
      let data: WorkerMessage = e.data;
      if (data.action === "FINISH") {
        this.destroy();
      }

    }
    // 在调用terminate后，执行回调onexit
    workerInstance.onexit = async () => {
      console.log("main thread terminate");
    }
    workerInstance.onerror = (err: ErrorEvent) => {
      console.error("main error message " + err.message);
      this.resetProp();
    }
  }

  async execute(uploadItem: TaskItemSendable) {
    this.uploadItem = uploadItem;
    this.isIdle = false;
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
  }
}

// worker池
export class WorkerPool {
  max: number = 10; // 最大进程数
  min: number = 0; // 最小进程数
  current: number = 0; // 当前进程数
  workerFileUri: string = ""; // worker路径
  workerItems: Array<UploadWorkerItem> = [];

  constructor(workerFileUri: string, max: number = 10, min: number = 0) {
    this.workerFileUri = workerFileUri;
    this.max = max;
    this.min = min;
  }

  /**
   * 执行线程池，给任务分配空闲进程
   * 1. 轮询当前线程是否有空闲
   * 2. 发现空闲线程则执行
   * 3. 如果没有空闲线程，则创建线程（如果current < max)
   */
  execute(context: common.Context, total: number) {
    this.stop();
    let items: Array<TaskItemSendable> = [];
    if (total < this.max) {
      this.max = total;
      for (let i=0; i<=this.max; i++) {
        const taskItemSendable = new TaskItemSendable(context, i, 1);
        items.push(taskItemSendable);
      }
    } else {
      let pageSize = Math.floor(total / this.max);
      let lastPageSize = pageSize + (total % this.max);
      for (let i=0; i<=this.max; i++) {
        let taskItemSendable: TaskItemSendable;
        if (i===this.max) {
          taskItemSendable = new TaskItemSendable(context, i*pageSize, lastPageSize);
        } else {
          taskItemSendable = new TaskItemSendable(context, i*pageSize, pageSize);
        }
        items.push(taskItemSendable);
      }
    }
    items.forEach((item: TaskItemSendable) => {
      const workerItem = this.newItem();
      workerItem.execute(item);
    });

    // 定时刷新任务状态
    const handleId = setInterval(() => {
      for (let i=0; i<this.workerItems.length; i++) {
        if (this.workerItems[i].isIdle) this.current --;
        if (this.current > 0) return ;
        Global.getInstance().processId = 0;
        // 完成了任务
        emitter.emit(Global.BACKUP_TASK_FINISH);
        clearInterval(handleId);
      }
    }, 1000);
  }

  newItem(): UploadWorkerItem {
    const item = new UploadWorkerItem();
    item.init(new worker.ThreadWorker(this.workerFileUri));
    this.workerItems.push(item);
    this.current += 1;
    return item;
  }

  // 清除空闲线程，直到min
  clear() {
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
  }

  // 终止所有运行中的线程
  stop() {
    for (let i = 0; i < this.workerItems.length; i++) {
      const item = this.workerItems[i];
      if (!item.isIdle) {
        item.destroy();
      }
    }
    this.workerItems = [];
    this.current = 0;
  }
}