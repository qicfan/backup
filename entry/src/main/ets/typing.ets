import { TaskItem } from "./models/TaskItem";
import { UploadItemSendable } from "./models/UploadItemSendable";

export enum LoginStatus { INIT = "init", NO_SERVER = "no_server", NO_LOGIN = "no_login", LOGIN = "login" }
export enum TaskDoing {NO = "no", YES = "yes"}
export enum ConfigGlobalStatus {NO = 0, YES = 1}
export enum AccessStatus {NO = 0, YES = 1}
export enum BackupType {ALL = 1, NEW = 2}
export enum DirRule {YMD = 'yyyy/mm/dd', YM = 'yyyy/mm', Y = 'yyyy'}
export enum LowBatteryStop {YES = 1, NO = 2}
export enum OnlyWIFIBackup {YES = 1, NO = 2}
export enum AUTOBackup {YES = 1, NO = 2}
export enum TaskType {AUTO = 1, Manual = 2}
export enum TaskStatus {WAIT = 1, PROCESS = 2, FINISH = 3}
export enum PhotoType {IMAGE = 1, VIDEO = 2}
export enum PhotoSubType {DEFAULT = 0, MOVING_PHOTO = 3, BURST = 4}
export enum TaskItemStatus {WAIT = 1, SUCCESS = 2, FAIL = 3, UPLOADING = 4}
export const SERVER_AUTH_FAILED_EVENT = 'server_auth_failed'; // 服务器验证失败
export interface DavResource {
  href: string
  displayName: string,
  type: string
}
export interface PhotoItem {
  uri: string
  media_type: number
  subtype: number
  display_name: string
  date_added: number
  date_modify: number
  size: number
}
export interface LocalUri {
  uri: string
  file_uri: string
}
export interface UploadEvent {
  ACTION: "START" | "STOP" | "UPDATE" | "FINISH" // START, STOP
  id: number // Task.id
  baseUrl: string
  username: string
  password: string
  backupRootPath: string
  cacheFileDir: string
}

export interface WorkerMessage {
  action: "START" | "FINISH" | "UPDATE_PROGRESS" | "ERROR" | "FILE_NOT_EXISTS" | "SERVER_NOT_CONNECT"
  code: number
  message: string
  taskItemId: number
  uploadedSize?: number
  type: number
}

export interface CopyWorkerMessage {
  action: "START" | "FINISH" | "UPDATE_PROGRESS" | "ERROR" | "FILE_NOT_EXISTS" | "SERVER_NOT_CONNECT"
  code: number
  message: string
  taskItemId: number
  imageSize: number
  videoSize: number
}

export interface UploadQueueItem {
  uploadItem: UploadItemSendable,
  taskItem: TaskItem
}