import { BackupType, TaskItemStatus } from "../typing";
import { intl } from '@kit.LocalizationKit';
import { relationalStore } from "@kit.ArkData";
import { DB } from "./DB";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { splitFileExt, strip } from "../utils/tools";
import { Config } from "./Config";
import { common } from "@kit.AbilityKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { Photos } from "../utils/photos";
import { ServerConfig } from "./Server";

@ObservedV2
export class TaskItem {
  id: number = 0;
  taskId: number = 0;
  name: string = ""
  size: number = 0;
  videoSize: number = 0;
  uploadedSize: number = 0;
  dateAdded: number = 0;
  dateModified: number = 0;
  uri: string = "";
  fileUri: string = "";
  remoteUri: string = "";
  videoUri: string = "";
  remoteVideoUri: string = "";
  photoType: photoAccessHelper.PhotoType = photoAccessHelper.PhotoType.IMAGE;
  subType: photoAccessHelper.PhotoSubtype = photoAccessHelper.PhotoSubtype.DEFAULT
  @Trace status: TaskItemStatus = TaskItemStatus.WAIT;
  @Trace failedReason: string = '';
  @Trace thumbnail: PixelMap | null = null;
  createdAt: number = 0;
  uploadedAt: number = 0;
  static TABLE_NAME = 'task_items'

  static getInstance(rs: relationalStore.ResultSet) {
    const taskItem = new TaskItem();
    taskItem.id = rs.getLong(rs.getColumnIndex('id'))
    taskItem.taskId = rs.getLong(rs.getColumnIndex('task_id'))
    taskItem.name = rs.getString(rs.getColumnIndex('name'))
    taskItem.uri = rs.getString(rs.getColumnIndex('uri'))
    taskItem.fileUri = rs.getString(rs.getColumnIndex('file_uri'))
    taskItem.remoteUri = rs.getString(rs.getColumnIndex('remote_uri'))
    taskItem.videoUri = rs.getString(rs.getColumnIndex('video_uri'))
    taskItem.remoteVideoUri = rs.getString(rs.getColumnIndex('remote_video_uri'))
    taskItem.failedReason = rs.getString(rs.getColumnIndex('failed_reason'))
    taskItem.size = rs.getLong(rs.getColumnIndex('size'))
    taskItem.videoSize = rs.getLong(rs.getColumnIndex('video_size'))
    taskItem.uploadedSize = rs.getLong(rs.getColumnIndex('uploaded_size'))
    taskItem.photoType = rs.getLong(rs.getColumnIndex('photo_type'))
    taskItem.subType = rs.getLong(rs.getColumnIndex('sub_type'))
    taskItem.status = rs.getLong(rs.getColumnIndex('status'))
    taskItem.createdAt = rs.getLong(rs.getColumnIndex('created_at'))
    taskItem.uploadedAt = rs.getLong(rs.getColumnIndex('uploaded_at'))
    taskItem.dateAdded = rs.getLong(rs.getColumnIndex('date_added'))
    taskItem.dateModified = rs.getLong(rs.getColumnIndex('date_modified'))
    return taskItem;
  }

  static async getById(id: number) {
    let item: TaskItem | undefined = undefined;
    let predicates = new relationalStore.RdbPredicates(TaskItem.TABLE_NAME);
    predicates.equalTo("id", id)
    try {
      const rs = await DB.getInstance().store?.query(predicates);
      if (rs === undefined || rs.rowCount <= 0) {
        return item;
      }
      while (rs.goToNextRow()) {
        item = TaskItem.getInstance(rs);
      }
      rs.close();
    } catch (error) {
      let err = error as BusinessError;
      console.log(`${err.code} => ${err.message}`)
    } finally {
      return item;
    }
  }

  static async getByUri(uri: string) {
    let item: TaskItem | undefined = undefined;
    let predicates = new relationalStore.RdbPredicates(TaskItem.TABLE_NAME);
    predicates.equalTo("uri", uri)
    try {
      const rs = await DB.getInstance().store?.query(predicates);
      if (rs === undefined || rs.rowCount <= 0) {
        return item;
      }
      while (rs.goToNextRow()) {
        item = TaskItem.getInstance(rs);
      }
      rs.close();
    } catch (error) {
      let err = error as BusinessError;
      console.log(`${err.code} => ${err.message}`)
    } finally {
      return item;
    }
  }

  static async uploadingToWait() {
    const updateBucket: relationalStore.ValuesBucket = {
      "status": TaskItemStatus.WAIT,
    };
    let predicates = new relationalStore.RdbPredicates(TaskItem.TABLE_NAME);
    predicates.equalTo("status", TaskItemStatus.UPLOADING)
    try {
      await DB.getInstance().store?.update(updateBucket, predicates);
      console.log(`已修改所有UPLOADING为WAIT`)
    } catch (err) {
      console.error(`task uploadingToWait failed, code is ${err.code},message is ${err.message}`);
    }
  }

  /**
   * 查询待备份列表
   * @param page
   * @param pageSize
   * @returns
   */
  static async getWaitList(page: number = 1, pageSize: number = 100): Promise<TaskItem[]> {
    const offset = (page - 1) * pageSize;
    const SQL = `SELECT * FROM ${TaskItem.TABLE_NAME} WHERE status IN (?, ?, ?) ORDER BY id ASC LIMIT ?, ?`;
    try {
      const rs = await DB.getInstance().store?.querySql(SQL, [TaskItemStatus.WAIT, TaskItemStatus.UPLOADING, TaskItemStatus.FAIL, offset, pageSize]);
      if (rs === undefined || rs.rowCount <= 0) {
        return [];
      }
      const items: TaskItem[] = [];
      while (rs.goToNextRow()) {
        const taskItem = TaskItem.getInstance(rs);
        items.push(taskItem)
      }
      rs.close();
      return items
    } catch (error) {
      let err = error as BusinessError;
      console.log(`${err.code} => ${err.message}`)
      return [];
    }
  }

  /**
   * 查询待备份列表
   * @param page
   * @param pageSize
   * @returns
   */
  static async getSuccessList(page: number = 1, pageSize: number = 100): Promise<TaskItem[]> {
    const offset = (page - 1) * pageSize;
    const SQL = `SELECT * FROM ${TaskItem.TABLE_NAME} WHERE status=? ORDER BY id ASC LIMIT ?, ?`;
    try {
      const rs = await DB.getInstance().store?.querySql(SQL, [TaskItemStatus.SUCCESS, offset, pageSize]);
      if (rs === undefined || rs.rowCount <= 0) {
        return [];
      }
      const items: TaskItem[] = [];
      while (rs.goToNextRow()) {
        const taskItem = TaskItem.getInstance(rs);
        items.push(taskItem)
      }
      rs.close();
      return items
    } catch (error) {
      let err = error as BusinessError;
      console.log(`${err.code} => ${err.message}`)
      return [];
    }
  }

  static getWaitCount(): number {
    const SQL = `SELECT * FROM ${TaskItem.TABLE_NAME} WHERE status IN (?, ?, ?)`;
    try {
      const rs = DB.getInstance().store?.querySqlSync(SQL, [TaskItemStatus.WAIT, TaskItemStatus.UPLOADING, TaskItemStatus.FAIL]);
      if (rs === undefined || rs.rowCount <= 0) {
        return 0;
      }
      const c = rs.rowCount;
      rs.close();
      return c;
    } catch (error) {
      let err = error as BusinessError;
      console.log(`${err.code} => ${err.message}`)
      return 0;
    }
  }

  static async getUploadingResultCount(): Promise<number> {
    const SQL = `SELECT * FROM ${TaskItem.TABLE_NAME} WHERE status IN (?, ?)`;
    try {
      const rs = await DB.getInstance().store?.querySql(SQL, [TaskItemStatus.WAIT, TaskItemStatus.UPLOADING]);
      if (rs === undefined || rs.rowCount <= 0) {
        return 0;
      }
      const c = rs.rowCount;
      rs.close();
      return c;
    } catch (error) {
      let err = error as BusinessError;
      console.log(`${err.code} => ${err.message}`)
      return 0;
    }
  }

  static getSuccessCount(): number {
    const SQL = `SELECT * FROM ${TaskItem.TABLE_NAME} WHERE status=?`;
    try {
      const rs = DB.getInstance().store?.querySqlSync(SQL, [TaskItemStatus.SUCCESS]);
      if (rs === undefined || rs.rowCount <= 0) {
        return 0;
      }
      const c = rs.rowCount;
      rs.close();
      return c;
    } catch (error) {
      let err = error as BusinessError;
      console.log(`${err.code} => ${err.message}`)
      return 0;
    }
  }

  static getFailedCount(): number {
    const SQL = `SELECT * FROM ${TaskItem.TABLE_NAME} WHERE status=?`;
    try {
      const rs = DB.getInstance().store?.querySqlSync(SQL, [TaskItemStatus.FAIL]);
      if (rs === undefined || rs.rowCount <= 0) {
        return 0;
      }
      const c = rs.rowCount;
      rs.close();
      return c;
    } catch (error) {
      let err = error as BusinessError;
      console.log(`${err.code} => ${err.message}`)
      return 0;
    }
  }

  /**
   * 收集相册照片信息，决定是否创建任务
   *
   */
  static async createTask(ctx: Context, config: Config) {
    let lastTimestamp: number = 0;
    if (config.backupType === BackupType.NEW) {
      // 只备份新数据，开始时间是APP第一次打开时间
      lastTimestamp = config.createdAt;
    }
    let predicates = new relationalStore.RdbPredicates(TaskItem.TABLE_NAME);
    predicates.orderByDesc('id').limitAs(1)
    const rs = await DB.getInstance().store?.query(predicates)
    console.log(`查询最后一条文件记录，返回数: ${rs?.rowCount}`)
    if (rs !== undefined && rs.rowCount > 0) {
      rs.goToNextRow()
      lastTimestamp = rs.getLong(rs.getColumnIndex('created_at'))
      console.log(`查询到的最后一次的时间1：${lastTimestamp}`)
    }
    console.log(`查询到的最后一次的时间2：${lastTimestamp}`)
    rs?.close();
    let page = 1;
    const pageSize = 100;
    let total = 0;
    while (true) {
      // 1. 收集相册内容，并且写入taskItem表
      const items = await Photos.getPhotos(ctx, lastTimestamp, page, pageSize)
      // 写入数据库
      if (items.length === 0) {
        console.log(`本次未查询到照片数据`)
        break;
      }
      total += items.length
      if (items.length < pageSize) {
        break;
      }
      page++
    }
    console.log(`生成的待备份总数：${total}`)
    return total > 0
  }

  async getThumbnail(ctx: Context, size: number): Promise<PixelMap> {
    const asset = await Photos.getPhotoAssetByUri(ctx, this.uri);
    if (asset === null || asset === undefined) throw new Error("照片不存在");
    const pm = await asset.getThumbnail({width: size, height: size})
    return pm;
  }

  // 生成本地文件路径
  makeUri(ctx: Context) {
    let context = ctx as common.UIAbilityContext;
    let filesDir = context.cacheDir;
    let filePath = `${filesDir}/${this.name}`;
    this.fileUri = filePath;
    const datePath = this.makeDatePath();
    let uri = `${datePath}/${this.name}`;
    this.remoteUri = uri;
    if (this.photoType === photoAccessHelper.PhotoType.IMAGE &&
      this.subType == photoAccessHelper.PhotoSubtype.MOVING_PHOTO) {
      const tmpFe = splitFileExt(this.name);
      const videoName = `${tmpFe[1]}.mp4`;
      this.videoUri = this.fileUri.replace(this.name, videoName);
      this.remoteVideoUri = this.remoteUri.replace(this.name, videoName);
    }
  }

  makeDatePath() {
    const date = new Date(this.dateAdded * 1000)
    let dateFormat: intl.DateTimeFormat = new intl.DateTimeFormat('zh-CN', {
      dateStyle: 'short',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    return dateFormat.format(date);
  }

  // 从数据库中查询最新的值
  async fetch() {
    let predicates = new relationalStore.RdbPredicates(TaskItem.TABLE_NAME);
    predicates.equalTo("id", this.id)
    try {
      const rs = await DB.getInstance().store?.query(predicates);
      if (!rs || rs.rowCount <= 0) {
        return false
      }
      while (rs.goToNextRow()) {
        this.name = rs.getString(rs.getColumnIndex('name'))
        this.taskId = rs.getLong(rs.getColumnIndex('task_id'))
        this.id = rs.getLong(rs.getColumnIndex('id'))
        this.uri = rs.getString(rs.getColumnIndex('uri'))
        this.fileUri = rs.getString(rs.getColumnIndex('file_uri'))
        this.remoteUri = rs.getString(rs.getColumnIndex('remote_uri'))
        this.videoUri = rs.getString(rs.getColumnIndex('video_uri'))
        this.remoteVideoUri = rs.getString(rs.getColumnIndex('remote_video_uri'))
        this.failedReason = rs.getString(rs.getColumnIndex('failed_reason'))
        this.size = rs.getLong(rs.getColumnIndex('size'))
        this.videoSize = rs.getLong(rs.getColumnIndex('video_size'))
        this.uploadedSize = rs.getLong(rs.getColumnIndex('uploaded_size'))
        this.photoType = rs.getLong(rs.getColumnIndex('photo_type'))
        this.subType = rs.getLong(rs.getColumnIndex('sub_type'))
        this.status = rs.getLong(rs.getColumnIndex('status'))
        this.createdAt = rs.getLong(rs.getColumnIndex('created_at'))
        this.uploadedAt = rs.getLong(rs.getColumnIndex('uploaded_at'))
        this.dateAdded = rs.getLong(rs.getColumnIndex('date_added'))
        this.dateModified = rs.getLong(rs.getColumnIndex('date_modified'))
        return true;
      }
    } catch (e) {
      let err = e as BusinessError;
      console.log(`${err.code} => ${err.message}`)
      return false;
    }
    return false;
  }

  async start() {
    this.status = TaskItemStatus.UPLOADING;
    this.updateStatus();
  }

  // 将状态修改为执行中
  async success() {
    this.status = TaskItemStatus.SUCCESS;
    this.uploadedAt = Math.floor(Date.now() / 1000);
    await this.updateStatus();
  }

  async failed(reason?: string) {
    this.status = TaskItemStatus.FAIL;
    if (reason) {
      this.failedReason = reason;
    }
    await this.updateStatus();
  }

  // 将状态修改为执行中
  async wait() {
    this.status = TaskItemStatus.WAIT;
    await this.updateStatus();
  }

  async updateStatus() {
    const updateBucket: relationalStore.ValuesBucket = {
      "status": this.status,
      "failed_reason": this.failedReason,
      "uploaded_at": this.uploadedAt
    };
    let predicates = new relationalStore.RdbPredicates(TaskItem.TABLE_NAME);
    predicates.equalTo("id", this.id)
    try {
      await DB.getInstance().store?.update(updateBucket, predicates);
    } catch (err) {
      console.error(`task Insert failed, code is ${err.code},message is ${err.message}`);
    }
  }

  async updateSize(size: number, videoSize: number) {
    this.size = size;
    this.videoSize = videoSize;
    this.uploadedAt = Math.floor(Date.now() / 1000);
    const updateBucket: relationalStore.ValuesBucket = {
      "size": this.size,
      "video_size": this.videoSize,
      "uploaded_at": this.uploadedAt
    };
    let predicates = new relationalStore.RdbPredicates(TaskItem.TABLE_NAME);
    predicates.equalTo("id", this.id)
    try {
      await DB.getInstance().store?.update(updateBucket, predicates);
    } catch (err) {
      console.error(`task item update size failed, code is ${err.code},message is ${err.message}`);
    }
  }

  async updateUploadedSize(uploadedSize: number) {
    this.uploadedSize = uploadedSize;
    const updateBucket: relationalStore.ValuesBucket = {
      "uploaded_size": this.uploadedSize,
    };
    let predicates = new relationalStore.RdbPredicates(TaskItem.TABLE_NAME);
    predicates.equalTo("id", this.id)
    try {
      await DB.getInstance().store?.update(updateBucket, predicates);
    } catch (err) {
      console.error(`task item update uploadedSize failed, code is ${err.code},message is ${err.message}`);
    }
  }

  async save() {
    const item = await TaskItem.getByUri(this.uri);
    if (item !== undefined) {
      // 已经存在了，不处理
      return false;
    }
    const insertBucket: relationalStore.ValuesBucket = {
      "task_id": this.taskId,
      "name": this.name,
      "uri": this.uri,
      "size": this.size,
      "video_size": this.videoSize,
      "uploaded_size": this.uploadedSize,
      "file_uri": this.fileUri,
      "remote_uri": this.remoteUri,
      "video_uri": this.videoUri,
      "remote_video_uri": this.remoteVideoUri,
      "failed_reason": this.failedReason,
      "photo_type": this.photoType,
      "sub_type": this.subType,
      "status": this.status,
      "created_at": this.createdAt,
      "uploaded_at": this.uploadedAt,
      "date_added": this.dateAdded,
      "date_modified": this.dateModified,
    };
    try {
      await DB.getInstance().store?.insert(TaskItem.TABLE_NAME, insertBucket,
        relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
      return true;
    } catch (err) {
      console.error(`task items ${this.remoteUri} insert failed, code is ${err.code},message is ${err.message}`);
      return false;
    }
  }

  getFullRemoteUri(remoteUri: string, hasBaseUri: boolean = false) {
    const server = ServerConfig.getInstance();
    const config = Config.getInstance();
    let url: string = "";
    if (hasBaseUri) {
      url = strip(server.server, '/')
    }
    const rootPath = strip(config.backupRootPath, '/');
    url += `${rootPath}/${remoteUri}`;
    return url;
  }
}