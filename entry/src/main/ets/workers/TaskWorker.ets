import { ErrorEvent, MessageEvents, ThreadWorkerGlobalScope, url, util, worker } from '@kit.ArkTS';
import { common, sendableContextManager } from '@kit.AbilityKit';
import { BusinessError, emitter, request } from '@kit.BasicServicesKit';
import { base64Encode, deleteFile, fileSize, getMimeTypeFromExtension, ltrip, strip } from '../utils/tools';
import { RequestReturn } from '../utils/webdav';
import { rcp } from '@kit.RemoteCommunicationKit';
import { SERVER_AUTH_FAILED_EVENT, TaskItemStatus } from '../typing';
import { DB } from '../models/DB';
import { relationalStore } from '@kit.ArkData';
import { Global } from '../models/Global';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { Photos } from '../utils/photos';
import { TaskItemSendable } from '../models/TaskItemSendable';


const workerPort: ThreadWorkerGlobalScope = worker.workerPort;
const TABLE_NAME = "task_items";
const db: DB = DB.getInstance();
let TOTAL: number = 0;
let FINISH: number = 0;
/**
 * Defines the event handler to be called when the worker thread receives a message sent by the host thread.
 * The event handler is executed in the worker thread.
 *
 * @param event message data
 */
workerPort.onmessage = (event: MessageEvents) => {
  // console.log(`上传线程收到消息：${JSON.stringify(event.data)}`)
  TOTAL = event.data.limit;
  doTask(event.data).then(() => {});
  const intervalHandlerId = setInterval(() => {
    // console.log(`定时检查子线程任务状态：总计：${TOTAL}， 已完成：${FINISH}`)
    if (FINISH < TOTAL) {
      console.log(`${FINISH} / ${TOTAL}`)
      return;
    }
    workerPort.postMessage({
      action: "FINISH"
    })
    clearInterval(intervalHandlerId);
  }, 1000);
};

/**
 * Defines the event handler to be called when the worker receives a message that cannot be deserialized.
 * The event handler is executed in the worker thread.
 *
 * @param event message data
 */
workerPort.onmessageerror = (event: MessageEvents) => {
};

/**
 * Defines the event handler to be called when an exception occurs during worker execution.
 * The event handler is executed in the worker thread.
 *
 * @param event error message
 */
workerPort.onerror = (event: ErrorEvent) => {
};

let session: rcp.Session;

async function updateSerConfig(server: string, username: string, password: string) {
  console.log(`username=${username}, password=${password}`)
  session?.close()
  session = rcp.createSession({
    // baseAddress: server,
    headers: { "Accept": "text/plain,text/html,application/xml" },
    requestConfiguration: {
      transfer: {
        timeout: { connectMs: 3000 }
      },
      security: {
        serverAuthentication: {
          credential: {
            username: username,
            password: password
          },
          authenticationType: "basic"
        }
      }
    }
  });
}

function getRealUrl(server: string, backupRootPath: string, path: string) {
  let base = strip(server, '/') + '/' +  ltrip(backupRootPath, '/')
  base = strip(base, '/')
  path = ltrip(strip(path, '/'), '/')
  if (path == '/' || path == '') {
    return base
  }
  return `${base}/${path}`
}

async function mkRemotePath(remoteUri: string, server: string, backupRootPath: string): Promise<boolean> {
  remoteUri = strip(remoteUri, '/')
  const dirList: string[] = remoteUri.split('/')
  dirList.pop();
  // 检查路径是否已经存在
  let fullPath = getRealUrl(server, backupRootPath, dirList.join('/'))
  const rs = await colExists(fullPath)
  if (rs) {
    return true;
  }
  let currentPath = getRealUrl(server, backupRootPath, "/")
  for (let dir of dirList) {
    // 创建目录
    currentPath += `/${dir}`;
    // console.log(`创建远程目录: ${currentPath}`);
    let rs = await colExists(currentPath)
    if (rs) {
      continue
    }
    const rr = await mkDir(currentPath);
    if ((rr.statusCode >= 200 && rr.statusCode < 300) || rr.statusCode == 405) {
      continue
    } else {
      // 创建目录失败
      console.error(`创建目录 ${currentPath} 失败：${rr.message}, code: ${rr.statusCode}}`);
      return false;
    }
  }
  return true;
}

// 发送请求
async function rcpRequest(req: rcp.Request) {
  const requestReturn: RequestReturn = new RequestReturn();
  try {
    const resp = await session?.fetch(req);
    if (resp === undefined) {
      requestReturn.statusCode = 500;
      requestReturn.success = false;
      requestReturn.message = "请求失败"
      return requestReturn;
    }
    // console.log(`${req.method} ${req.url} | ${resp.statusCode}`)
    // console.log(`headers: ${JSON.stringify(resp.headers)}`);
    // 输出响应的body内容，resp.body为ArrayBuffer类型
    // const decoder = new util.TextDecoder();
    // let body: string = decoder.decodeToString(new Uint8Array(resp.body));
    // console.log(body)

    requestReturn.statusCode = resp.statusCode;
    requestReturn.headers = resp.headers;
    if (resp.statusCode === 401) {
      requestReturn.message = "用户名密码不正确"
      requestReturn.success = false;
      // 触发登录失败事件
      emitter.emit(SERVER_AUTH_FAILED_EVENT);
    }

    if (resp.statusCode === 500) {
      requestReturn.message = "服务器内部错误，请检查服务器是否正常。"
      requestReturn.success = false;
    }
    if (resp.statusCode === 407) {
      requestReturn.message = "目录不存在，请先创建目录"
      requestReturn.success = false;
    }
    if (resp.statusCode === 507) {
      requestReturn.message = "服务器存储空间不足"
      requestReturn.success = false;
    }
    if (requestReturn.statusCode >= 200 && requestReturn.statusCode < 300) {
      // 正常
      requestReturn.statusCode = 200
      requestReturn.body = resp.toString() ?? "";
      requestReturn.success = true;
    } else {
      requestReturn.success = false;
    }
  } catch (err) {
    requestReturn.statusCode = 500
    requestReturn.success = false;
    if (err.code === 1007900028) {
      requestReturn.message = "服务器超时，请检查服务器地址或端口是否正确"
    } else {
      requestReturn.message = "连接失败，请检查本机网络或者联系作者，错误码：" + err.code + ", 错误：" + err.message
    }
  }
  return requestReturn;
}

// 是否存在
async function fileExists(path: string, size: number) {
  // console.log(`查询${path}是否存在`)
  const req = new rcp.Request(path, "PROPFIND", { "Depth": "0" });
  const rr = await rcpRequest(req);
  // 不存在
  if (!rr.success) {
    // console.log(`文件请求不成功，code: ${rr.statusCode}, msg: ${rr.message}`)
    return 0;
  }
  let remoteSize: number = 0;
  let remoteSizeArr: string | string[] | undefined = rr.headers['content-length'];
  if (remoteSizeArr === undefined) {
    remoteSize = 0;
  } else if (typeof remoteSizeArr !== 'string') {
    remoteSize = parseInt(remoteSizeArr[0]);
  } else {
    remoteSize = parseInt(remoteSizeArr)
  }
  // console.log(`文件存在，比较大小是否一致, ${remoteSize}=>${size}`)
  if (remoteSize == size) {
    return 1
  } else {
    return 2;
  }
}

// 是否文件夹存在
async function colExists(path: string) {
  if (!path.endsWith('/')) {
    path = path + '/';
  }
  // console.log(`查询${path}是否存在`)
  const req = new rcp.Request(path, "PROPFIND", { "Depth": "0" });
  const rr = await rcpRequest(req);
  return rr.success;
}

// 创建目录
async function mkDir(path: string) {
  if (!path.endsWith('/')) {
    path += '/'
  }
  const req = new rcp.Request(path, "MKCOL");
  return await rcpRequest(req);
}

// 删除文件
async function rcpDelete(path: string) {
  const req = new rcp.Request(path, "DELETE");
  return await rcpRequest(req);
}

function start(taskItemId: number) {
  const updateBucket: relationalStore.ValuesBucket = {
    "status": TaskItemStatus.UPLOADING,
  };
  let predicates = new relationalStore.RdbPredicates(TABLE_NAME);
  predicates.equalTo("id", taskItemId)
  try {
    db.store?.updateSync(updateBucket, predicates);
    // console.log(`${taskItemId}已修改为UPLOADING`);
    emitter.emit(Global.UPDATE_TASK_ITEM_EVENT + '_' + taskItemId, {
      data: {
        id: taskItemId,
        action: 'START',
        uploadedSize: 0,
        reason: ''
      }
    });
  } catch (err) {
    console.error(`task success failed, code is ${err.code},message is ${err.message}`);
  }
}

function success(taskItemId: number) {
  const updateBucket: relationalStore.ValuesBucket = {
    "status": TaskItemStatus.SUCCESS,
    "failed_reason": "",
    "uploaded_at": Math.floor(Date.now() / 1000)
  };
  let predicates = new relationalStore.RdbPredicates(TABLE_NAME);
  predicates.equalTo("id", taskItemId)
  try {
    db.store?.updateSync(updateBucket, predicates);
    // console.log(`${taskItemId} 已备份.`)
  } catch (err) {
    console.error(`task success failed, code is ${err.code},message is ${err.message}`);
  }
}

function fail(taskItemId: number, reason: string) {
  const updateBucket: relationalStore.ValuesBucket = {
    "status": TaskItemStatus.FAIL,
    "failed_reason": reason
  };
  let predicates = new relationalStore.RdbPredicates(TABLE_NAME);
  predicates.equalTo("id", taskItemId)
  try {
    db.store?.updateSync(updateBucket, predicates);
  } catch (err) {
    console.error(`task success failed, code is ${err.code},message is ${err.message}`);
  }
}

function updateProgress(taskItemId: number, uploadedSize: number) {
  const updateBucket: relationalStore.ValuesBucket = {
    "uploaded_size": uploadedSize,
  };
  let predicates = new relationalStore.RdbPredicates(TABLE_NAME);
  predicates.equalTo("id", taskItemId)
  try {
    db.store?.updateSync(updateBucket, predicates);
  } catch (err) {
    console.error(`task item update uploadedSize failed, code is ${err.code},message is ${err.message}`);
  }
}

function updateSize(taskItemId: number, size: number, videoSize: number) {
  const updateBucket: relationalStore.ValuesBucket = {
    "size": size,
    "video_size": videoSize,
    "uploaded_at": Math.floor(Date.now() / 1000)
  };
  let predicates = new relationalStore.RdbPredicates(TABLE_NAME);
  predicates.equalTo("id", taskItemId)
  try {
    db.store?.updateSync(updateBucket, predicates);
  } catch (err) {
    console.error(`task item update size failed, code is ${err.code},message is ${err.message}`);
  }
  return;
}

async function copyFile(context: common.Context, taskItemId: number, photoType: photoAccessHelper.PhotoType, subType: photoAccessHelper.PhotoSubtype,
  size: number, uri: string, imageUri: string, videoUri: string): Promise<number[] | null> {
  let videoSize: number;
  if (subType === photoAccessHelper.PhotoSubtype.MOVING_PHOTO) {
    // 动态图，请求封面图片+视频
    const rs = await Photos.saveMovingPhoto(context, uri, imageUri, videoUri);
    if (rs !== "success") {
      return null;
    }
    videoSize = fileSize(videoUri);
  } else {
    // 普通图片和视频
    if (photoType === photoAccessHelper.PhotoType.IMAGE) {
        const rs = await Photos.saveImage(context, uri, imageUri, size);
        if (rs !== "success") {
          throw new Error(rs);
        }
    }
    if (photoType === photoAccessHelper.PhotoType.VIDEO) {
        const rs = await Photos.saveVideo(context, uri, imageUri, size);
        if (rs !== "success") {
          throw new Error(rs);
        }
    }
    videoSize = 0;
  }
  updateSize(taskItemId, size, videoSize);
  return [size, videoSize];
}

function getBase64Auth(username: string, password: string): string {
  return base64Encode(`${username}:${password}`)
}

function getWaitList(offset: number = 1, limit: number = 100): relationalStore.ResultSet | null {
  const SQL = `SELECT * FROM task_items WHERE status IN (1,3,4) ORDER BY id DESC LIMIT ${limit} OFFSET ${offset}`;
  try {
    const rs = db.store?.querySqlSync(SQL);
    // const rs = db.store?.querySqlSync(SQL);
    if (rs === undefined || rs.rowCount <= 0) {
      rs?.close();
      console.log(`查询结果是undefine或者返回结果数：${rs?.rowCount}, ${offset}, ${limit}`);
      return null;
    }
    return rs;
  } catch (error) {
    let err = error as BusinessError;
    console.log(`${err.code} => ${err.message}`)
    return null;
  }
}

function getFullRemoteUri(remoteUri: string, hasBaseUri: boolean, server: string, backupRootPath: string) {
  let url: string = "";
  if (hasBaseUri) {
    url = strip(server, '/')
  }
  const rootPath = ltrip(strip(backupRootPath, '/'), '/');
  url += `/${rootPath}/${remoteUri}`;
  return url;
}

async function upload(context: common.Context, taskItemId: number, serverBaseUrl: string, backupRootPath: string,
  imageUri: string, filesDir: string, remoteUri: string, size: number, name: string, auth: string): Promise<boolean> {

  // 上传文件
  const srcImageUri: string = imageUri.replace(filesDir, 'internal://cache');
  let oldRemoteUri = remoteUri
  remoteUri = getFullRemoteUri(remoteUri, true, serverBaseUrl, backupRootPath);
  const mkRP = await mkRemotePath(oldRemoteUri, serverBaseUrl, backupRootPath);
  if (!mkRP) {
    fail(taskItemId, "在服务器上创建备份目录失败");
    return false;
  }
  try {
    // 检查文件是否已存在
    let existsRR: number = await fileExists(remoteUri, size);
    if (existsRR === 2) {
      // 存在，不一致，删除远程文件
      await rcpDelete(remoteUri)
      existsRR = 0;
    }
    if (existsRR === 1) {
      // 已经上传完成
      success(taskItemId);
      deleteFile(imageUri);
      FINISH ++;
      emitter.emit(Global.UPDATE_TASK_ITEM_EVENT + '_' + taskItemId, {
        data: {
          id: taskItemId,
          action: 'SUCCESS',
          uploadedSize: size,
          reason: ''
        }
      });
      return true;
    }
  } catch (e) {
    console.error(`rcp请求报错：${e.code}, ${e.message}`);
    fail(taskItemId, e.message);
    deleteFile(imageUri);
    FINISH ++;
    emitter.emit(Global.UPDATE_TASK_ITEM_EVENT + '_' + taskItemId, {
      data: {
        id: taskItemId,
        action: 'FAIL',
        uploadedSize: size,
        reason: e.message
      }
    });
    return false;
  }
  // 上传任务配置项
  const files: Array<request.File> = [{
    filename: name,
    name: 'file',
    uri: srcImageUri,
    type: getMimeTypeFromExtension(imageUri)
  }]
  const uploadConfig: request.UploadConfig = {
    url: remoteUri,
    header: { 'Authorization': 'Basic ' + auth },
    method: 'PUT',
    files: files,
    data: []
  }
  try {
    const uploadTask: request.UploadTask = await request.uploadFile(context, uploadConfig);
    uploadTask.on('complete', () => {
      // 删除文件
      deleteFile(imageUri);
      success(taskItemId);
      FINISH ++;
      emitter.emit(Global.UPDATE_TASK_ITEM_EVENT + '_' + taskItemId, {
        data: {
          id: taskItemId,
          action: 'SUCCESS',
          uploadedSize: size,
          reason: ""
        }
      });
      uploadTask.delete().then();
    });
    uploadTask.on('fail', (taskStates: Array<request.TaskState>) => {
      // 删除文件
      deleteFile(imageUri);
      console.info("upOnFail taskState:" + JSON.stringify(taskStates[0]));
      fail(taskItemId, taskStates[0].message);
      FINISH ++;
      emitter.emit(Global.UPDATE_TASK_ITEM_EVENT + '_' + taskItemId, {
        data: {
          id: taskItemId,
          action: 'FAIL',
          uploadedSize: size,
          reason: taskStates[0].message
        }
      });
      uploadTask.delete().then();
    });
    uploadTask.on("progress", (uploadedSize: number) => {
      // 更新已上传进度
      updateProgress(taskItemId, uploadedSize);
      emitter.emit(Global.UPDATE_TASK_ITEM_EVENT + '_' + taskItemId, {
        data: {
          id: taskItemId,
          action: 'PROGRESS',
          uploadedSize: uploadedSize,
          reason: ''
        }
      });
    })
  } catch (error) {
    let err: BusinessError = error as BusinessError;
    console.error(`创建上传任务失败： ${srcImageUri} => ${remoteUri}, code is ${err.code}, message is ${err.message}`);
    fail(taskItemId, err.message);
    deleteFile(imageUri);
    FINISH ++;
    emitter.emit(Global.UPDATE_TASK_ITEM_EVENT + '_' + taskItemId, {
      data: {
        id: taskItemId,
        action: 'FAIL',
        uploadedSize: size,
        reason: err.message
      }
    });
    return false;
  }
  return true;
}

async function doTask(uploadItem: TaskItemSendable): Promise<boolean> {
  const context: common.Context = sendableContextManager.convertToContext(uploadItem.sendableContext);
  // console.log(`数据库路径：${context.databaseDir}，缓存路径：${context.cacheDir}`)
  await DB.init(context);
  updateSerConfig(uploadItem.serverBaseUrl, uploadItem.serverUsername, uploadItem.serverPassword);
  const filesDir: string = context.cacheDir;
  const auth = getBase64Auth(uploadItem.serverUsername, uploadItem.serverPassword);
  // 查找数据
  const resultSet = getWaitList(uploadItem.offset, uploadItem.limit);
  if (resultSet === null) {
    FINISH = TOTAL;
    console.log(`子线程无法查询到待备份列表`);
    return false;
  }
  // TOTAL = resultSet.rowCount;
  while (resultSet.goToNextRow()) {
      // 先复制文件
    const taskItemId = resultSet.getLong(resultSet.getColumnIndex('id'));
    // console.log(`${taskItemId} 开始上传`);
    const uri: string = resultSet.getString(resultSet.getColumnIndex('uri'));
    const imageUri: string = resultSet.getString(resultSet.getColumnIndex('file_uri'));
    const name: string = resultSet.getString(resultSet.getColumnIndex('name'));
    let remoteUri: string = resultSet.getString(resultSet.getColumnIndex('remote_uri'));
    const videoUri: string = resultSet.getString(resultSet.getColumnIndex('video_uri'));
    let videoRemoteUri: string = resultSet.getString(resultSet.getColumnIndex('remote_video_uri'));
    const photoType = resultSet.getLong(resultSet.getColumnIndex('photo_type'));
    const subType = resultSet.getLong(resultSet.getColumnIndex('sub_type'));
    const size = resultSet.getLong(resultSet.getColumnIndex('size'));
    try {
      start(taskItemId);
      const sizeArr = await copyFile(context, taskItemId, photoType, subType, size, uri, imageUri, videoUri);
      if (sizeArr === null) {
        // 复制文件失败，跳过
        fail(taskItemId, "导出照片出错，可能已被删除");
        console.log("导出照片出错，可能已被删除");
        continue;
      }
      const videoSize = sizeArr[1];
      await upload(context, taskItemId, uploadItem.serverBaseUrl, uploadItem.backupRootPath, imageUri, filesDir,
        remoteUri, size, name, auth);
      if (subType === photoAccessHelper.PhotoSubtype.MOVING_PHOTO) {
        // 上传动态照片的视频
        await upload(context, taskItemId, uploadItem.serverBaseUrl, uploadItem.backupRootPath, videoUri, filesDir,
          videoRemoteUri, videoSize, name, auth);
      }
    } catch (e) {
      console.log(`上传出错：code:${e.code}, msg:${e.message}`);
      FINISH ++;
      fail(taskItemId, e.message);
      deleteFile(imageUri);
      if (subType === photoAccessHelper.PhotoSubtype.MOVING_PHOTO) {
        deleteFile(videoUri);
      }
    }
  }
  resultSet.close();
  return true;
}

