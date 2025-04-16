import { AccessStatus, ConfigGlobalStatus, LoginStatus, TaskDoing } from "../typing"

@ObservedV2
export class Global {
  @Trace AccessStatus: AccessStatus = AccessStatus.NO;
  @Trace loginStatus: LoginStatus = LoginStatus.INIT // 默认正在初始化
  @Trace taskGlobalStatus: TaskDoing = TaskDoing.NO // 默认没有运行中的任务
  @Trace configGlobalStatus: ConfigGlobalStatus = ConfigGlobalStatus.NO; // 没有配置项
  @Trace processId: number = 0; // 运行中的任务

  static COLLECT_PHOTO_FINISH_EVENT = 'collect_photo_finish'; // 收集照片完成
  static START_COLLECT_PHOTO_EVENT = 'start_collect_photo'; // 触发始收集照片
  static START_WAIT_TASK_EVENT = 'start_wait_task'; // 触发任务执行
  static STOP_TASK_EVENT = 'stop_task'; // 触发任务停止
  static UPDATE_TASK_EVENT = 'update_task_event'; // 开始执行某个任务
}