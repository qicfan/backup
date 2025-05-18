import { sendableContextManager } from "@kit.AbilityKit";
import { Config } from "./Config";
import { ServerConfig } from "./Server";
import { TaskItem } from "./TaskItem";

export class TaskItemSendable {
  offset: number = 0;
  limit: number = 0;
  backupRootPath: string = ""
  serverBaseUrl: string = ""
  serverUsername: string = ""
  serverPassword: string = ""
  sendableContext: sendableContextManager.SendableContext;

  constructor(context: Context, offset: number , limit: number) {
    this.sendableContext = sendableContextManager.convertFromContext(context);
    this.offset = offset;
    this.limit = limit;
    this.backupRootPath = (Config.getInstance()).backupRootPath;
    const server = ServerConfig.getInstance();
    this.serverBaseUrl = server.server;
    this.serverUsername = server.username;
    this.serverPassword = server.password;
  }
}