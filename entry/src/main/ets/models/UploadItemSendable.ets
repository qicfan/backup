import { sendableContextManager } from "@kit.AbilityKit";
import { Config } from "./Config";
import { ServerConfig } from "./Server";
import { TaskItem } from "./TaskItem";

export class UploadItemSendable {
  taskItemId: number = 0; // 任务文件ID
  photoType: number = 0;
  subType: number = 0; // 文件名称
  imageUri: string = ""; // 图片资源路径
  videoUri: string = ""; // 动态图的视频文件路径
  name: string = ""; // 文件名称
  fileUri: string = ""; // 本地文件路径
  remoteUri: string = ""; // 远程文件路径
  fileSize: number = 0; // 文件大小
  type: number = 1 // 文件类型：1-普通图片或视频或动态图图片，2-动态图视频
  auth: string = ""; // 服务器验证token
  backupRootPath: string = ""
  serverBaseUrl: string = ""
  serverUsername: string = ""
  serverPassword: string = ""
  sendableContext: sendableContextManager.SendableContext;

  constructor(context: Context, taskItem: TaskItem, auth: string, type: number = 1) {
    this.sendableContext = sendableContextManager.convertFromContext(context);
    this.type = type;
    this.auth = auth;
    this.taskItemId = taskItem.id;
    this.name = taskItem.name;
    if (type === 1) {
      this.fileUri = taskItem.fileUri;
      this.remoteUri = taskItem.getFullRemoteUri(taskItem.remoteUri, true);
      this.fileSize = taskItem.size;
    } else {
      this.fileUri = taskItem.videoUri;
      this.remoteUri = taskItem.getFullRemoteUri(taskItem.remoteVideoUri, true);
      this.fileSize = taskItem.videoSize;
    }
    // const filesDir: string = context.cacheDir;
    // this.fileUri = this.fileUri.replace(filesDir, 'internal://cache')
    this.backupRootPath = (Config.getInstance()).backupRootPath;
    const server = ServerConfig.getInstance();
    this.serverBaseUrl = server.server;
    this.serverUsername = server.username;
    this.serverPassword = server.password;
  }
}