import { Queue } from '@kit.ArkTS';
import { TaskItem } from '../models/TaskItem';
import { ArkTSUtils } from '@kit.ArkTS'

// 上传队列
export class UploadQueue {
  private q: Queue<TaskItem> = new Queue()

  private static _instance: UploadQueue | null = null;

  static getInstance() {
    if (UploadQueue._instance === null) {
      UploadQueue._instance = new UploadQueue();
    }
    return UploadQueue._instance;
  }

  constructor() {
  }

  add(item: TaskItem) {
    this.q.add(item)
  }

  length() {
    return this.q.length
  }

  // 从队列中获取数据
  async read(): Promise<TaskItem | undefined> {
    return new Promise((resolve) => {
      if (this.length() === 0) {
        resolve(undefined)
        return
      }
      // let lock: ArkTSUtils.locks.AsyncLock = ArkTSUtils.locks.AsyncLock.request("upload_queue");
      // lock.lockAsync(() => {
        resolve(this.q.pop())
      // })
    })
  }

  clear() {
    // 清空队列
    while (this.q.length > 0) {
      this.q.pop()
    }
    this.q = new Queue<TaskItem>()
  }


}