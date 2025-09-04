
export enum FormStatus {DEFAULT=0, COLLECT=1, EXEC=2};
export enum LoginStatus { INIT = "init", NO_SERVER = "no_server", NO_LOGIN = "no_login", LOGIN = "login" }
export enum TaskDoing {NO = "no", YES = "yes"}
export enum ConfigGlobalStatus {NO = 0, YES = 1}
export enum AccessStatus {NO = 0, YES = 1}
export enum BackupType {ALL = 1, NEW = 2}
export enum DirRule {YMD = 'yyyy/mm/dd', YM = 'yyyy/mm', Y = 'yyyy'}
export enum LowBatteryStop {YES = 1, NO = 2}
export enum OnlyWIFIBackup {YES = 1, NO = 2}
export enum AUTOBackup {YES = 1, NO = 2}
export enum PhotoType {IMAGE = 1, VIDEO = 2}
export enum PhotoSubType {DEFAULT = 0, MOVING_PHOTO = 3, BURST = 4}
export enum TaskItemStatus {WAIT = 1, SUCCESS = 2, FAIL = 3, UPLOADING = 4}

export interface UploadEvent {
  path: string // 待备份的沙箱路径，包含文件名和backupRootPath，如MobileBackup/Huawei Pura X/2025/8/29/1111.jpg
  type: number // 待备份的资源类型：1-照片，2-视频，3-动态照片
  fileUri: string // 资源的系统路径
  token: string // 访问凭证
  server: string // 服务器地址
  live_photo_video_path: string // 动态照片的视频的路径
}

export interface WorkerMessage {
  action: "START" | "FINISH" | "UPDATE_PROGRESS" | "ERROR" | "FILE_NOT_EXISTS" | "SERVER_NOT_CONNECT"
  code: number
  message: string
  taskItemId: number
  uploadedSize?: number
  type: number
}

export interface WindowBreakpoint {
  currentHeightBreakpoint: string
  currentWidthBreakpoint: string
}
export interface TabItem {
  icon: Resource
  selectedIcon: Resource
  name: string
}