import { Queue } from "@kit.ArkTS";
import { TaskItem } from "../models/TaskItem";
import { UploadQueueItem } from "../typing";

export class TaskItemQueue {
  uploadItemQueue: Queue<UploadQueueItem> = new Queue<UploadQueueItem>();
  copyImageQueue: Queue<TaskItem> = new Queue<TaskItem>();

  private static _instance: TaskItemQueue | null = null;

  static getInstance() {
    if (TaskItemQueue._instance === null) {
      TaskItemQueue._instance = new TaskItemQueue();
    }
    return TaskItemQueue._instance;
  }
}