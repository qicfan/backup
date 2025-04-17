import { TaskItemStatus } from "../typing";
import { common } from "@kit.AbilityKit";
import { intl } from '@kit.LocalizationKit';
import { relationalStore } from "@kit.ArkData";
import { DB } from "./DB";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { copyPhoto, splitFileExt } from "../utils/tools";
import { WebDav } from "../utils/webdav";
import { Config } from "./Config";
import { Task } from "./Task";
import { Photos } from "../utils/photos";

export class TaskItem {
  id: number = 0;
  taskId: number = 0;
  name: string = ""
  size: number = 0;
  uploadedSize: number = 0;
  dateAdded: number = 0;
  dateModified: number = 0;
  uri: string = "";
  fileUri: string = "";
  remoteUri: string = "";
  photoType: photoAccessHelper.PhotoType = photoAccessHelper.PhotoType.IMAGE;
  subType: photoAccessHelper.PhotoSubtype = photoAccessHelper.PhotoSubtype.DEFAULT
  status: TaskItemStatus = TaskItemStatus.WAIT;
  createdAt: number = 0;
  uploadedAt: number = 0;

  static TABLE_NAME = 'task_items'
  public task: Task = new Task();
  public webdav: WebDav = new WebDav()
  public config: Config = new Config()
  public videoUri: string = ""
  public videoRemoteUri: string = ""

  updateWebDav(webdav: WebDav, config: Config) {
    this.webdav = webdav;
    this.config = config;
  }

  // 生成本地文件路径
  makeFileUri(ctx: Context) {
    let context = ctx as common.UIAbilityContext;
    let filesDir = context.cacheDir;
    let filePath = `${filesDir}/${this.name}`
    this.fileUri = filePath;
  }

  makeRemoteUri() {
    const datePath = this.makeDatePath();
    let uri = `${datePath}/${this.name}`;
    this.remoteUri = uri;
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

  static getInstance(rs: relationalStore.ResultSet) {
    const taskItem = new TaskItem();
    taskItem.id = rs.getLong(rs.getColumnIndex('id'))
    taskItem.taskId = rs.getLong(rs.getColumnIndex('task_id'))
    taskItem.name = rs.getString(rs.getColumnIndex('name'))
    taskItem.uri = rs.getString(rs.getColumnIndex('uri'))
    taskItem.fileUri = rs.getString(rs.getColumnIndex('file_uri'))
    taskItem.remoteUri = rs.getString(rs.getColumnIndex('remote_uri'))
    taskItem.size = rs.getLong(rs.getColumnIndex('size'))
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

  // 将状态修改为执行中
  async success() {
    this.status = TaskItemStatus.SUCCESS;
    this.uploadedAt = Math.floor(Date.now() / 1000);
    this.updateStatus();
  }

  async failed() {
    this.status = TaskItemStatus.FAIL;
    await this.updateStatus();
  }

  async updateStatus() {
    const updateBucket: relationalStore.ValuesBucket = {
      "status": this.status,
      "uploaded_at": this.uploadedAt
    };
    let predicates = new relationalStore.RdbPredicates(TaskItem.TABLE_NAME);
    predicates.equalTo("id", this.id)
    try {
      await DB.dbInstance?.store?.update(updateBucket, predicates);
    } catch (err) {
      console.error(`task Insert failed, code is ${err.code},message is ${err.message}`);
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
      await DB.dbInstance?.store?.update(updateBucket, predicates);
    } catch (err) {
      console.error(`task Insert failed, code is ${err.code},message is ${err.message}`);
    }
  }

  async save() {
    const insertBucket: relationalStore.ValuesBucket = {
      "task_id": this.taskId,
      "name": this.name,
      "uri": this.uri,
      "size": this.size,
      "uploaded_size": this.uploadedSize,
      "file_uri": this.fileUri,
      "remote_uri": this.remoteUri,
      "photo_type": this.photoType,
      "sub_type": this.subType,
      "status": this.status,
      "created_at": this.createdAt,
      "uploaded_at": this.uploadedAt,
      "date_added": this.dateAdded,
      "date_modified": this.dateModified,
    };
    try {
      await DB.dbInstance?.store?.insert(TaskItem.TABLE_NAME, insertBucket,
          relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
      // console.info(`task item insert row: ${rowId}`);
      return true;
    } catch (err) {
      console.error(`task items ${this.remoteUri} insert failed, code is ${err.code},message is ${err.message}`);
      return false;
    }
  }

  // 上传该图片
  // 1. 复制文件到沙箱中
  // 2. dav创建文件目录
  // 3. 检查文件是否存在，如果存在则检查状态是否完成，如果完成则跳过，如果未完成则删除
  // 4. 上传文件
  // 5. 修改状态
  async upload(ctx: Context): Promise<boolean> {
    if (this.status !== TaskItemStatus.WAIT) return true;
    const dirList: string[] = this.remoteUri.split('/').filter(part => part.length > 0);
    dirList.pop();
    const remoteUri = `${this.config.backupRootPath}${this.remoteUri}`
    // 检查文件是否存在
    const exists = await this.webdav.exists(remoteUri);
    if (exists) {
      this.updateUploadedSize(this.size)
      this.task.updateUploadedSize(this.size);
      this.success();
      return true;
    }
    let currentPath = `${this.config.backupRootPath}`;
    for (let dir of dirList) {
      // 创建目录
      currentPath += `/${dir}`;
      const rr = await this.webdav.mkDir(currentPath);
      if ((rr.statusCode >= 200 && rr.statusCode < 300) || rr.statusCode == 405) {
        continue
      } else {
        this.failed();
        // 创建目录失败
        console.log(`创建目录失败：${currentPath}`);
        return false;
      }
    }
    try {
      // 如果时动态图，则获取图片和视频分别上传
      if (this.photoType === photoAccessHelper.PhotoType.IMAGE && this.subType == photoAccessHelper.PhotoSubtype.MOVING_PHOTO) {
        // 生成视频文件名称
        const tmpFe = splitFileExt(this.name);
        const videoName = `${tmpFe[1]}.mp4`;
        this.videoUri = this.fileUri.replace(this.name, videoName);
        this.videoRemoteUri = this.remoteUri.replace(this.name, videoName);
        const rs = await Photos.saveMovingPhoto(ctx, this.uri, this.fileUri, this.videoUri)
        if (!rs) {
          // 保存动态图片失败
          return false;
        }
        let a = await this.webdav.upload(this);
        let b = await this.webdav.upload(this, 'video');
        return a && b;
      } else {
        copyPhoto(this.uri, this.size, this.fileUri);
        // 上传文件
        return await this.webdav.upload(this);
      }

    } catch (e) {
      console.log(`复制文件失败, code:${e.code}. msg:${e.message}`)
      return false;
    }
  }
}