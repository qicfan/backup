import { sendableContextManager } from "@kit.AbilityKit";
import { Config } from "./Config";
import { ServerConfig } from "./Server";
import { TaskItem } from "./TaskItem";

@Sendable
export class CopyItemSendable {
  photoType: number = 0;
  subType: number = 0; // 文件名称
  imageUri: string = ""; // 图片资源路径
  fileUri: string = ""; // 图片文件路径
  fileSize: number = 0; // 图片文件大小
  videoUri: string = ""; // 动态图的视频文件路径
  taskItemId: number = 0;
  sendableContext: sendableContextManager.SendableContext;

  constructor(context: Context, taskItem: TaskItem) {
    this.sendableContext = sendableContextManager.convertFromContext(context);
    this.taskItemId = taskItem.id;
    this.photoType = taskItem.photoType;
    this.subType = taskItem.subType;
    this.imageUri = taskItem.uri;
    this.fileUri = taskItem.fileUri;
    this.videoUri = taskItem.videoUri;
    this.fileSize = taskItem.size;
  }
}