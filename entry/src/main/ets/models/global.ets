import { LoginStatus, TaskGlobalStatus } from "../typing"

@ObservedV2
export class GlobalStatus {
  loginStatus: LoginStatus = LoginStatus.INIT // 默认正在初始化
  taskGlobalStatus: TaskGlobalStatus = TaskGlobalStatus.NO_TASK // 默认没有运行中的任务
}