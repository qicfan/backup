import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { connection } from '@kit.NetworkKit';
import { batteryInfo, BusinessError } from '@kit.BasicServicesKit';

export function copyPhoto(uri: string, size: number, destFilePath: string) {
  let destPath: fileIo.File;
  let file: fileIo.File;
  let fileStat: fileIo.Stat;
  try {
    destPath = fileIo.openSync(destFilePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
  } catch(e) {
    console.log(`创建临时文件${destFilePath}失败, code:${e.code}. msg:${e.message}`)
    return false;
  }
  try {
    file = fileIo.openSync(uri);
  } catch(e) {
    console.log(`打开${uri}失败, code:${e.code}. msg:${e.message}`)
    return false;
  }
  let buffSize = 4096;
  let buffer: ArrayBuffer = new ArrayBuffer(Math.min(buffSize, size));
  let off: number = 0;
  let len: number = fileIo.readSync(file.fd, buffer, { offset: off, length: buffSize });
  let readLen: number = 0;
  while (len > 0) {
    readLen += len;
    fileIo.writeSync(destPath.fd, buffer, { offset: off, length: buffSize })
    off = off + len;
    if ((size - readLen) < buffSize) {
      buffSize = size - readLen;
    }
    len = fileIo.readSync(file.fd, buffer, { offset: off, length: buffSize });
  }
  fileIo.closeSync(file.fd)
  fileIo.closeSync(destPath.fd)
  return true;
}


export function deletePhoto(filePath: string) {
  if (!filePath) {
    return;
  }
  try {
    fileIo.unlinkSync(filePath)
  } catch (e) {
    console.error(`删除文件错误，code:${e.code}, 错误信息：${e.message}`)
  }
  return
}

export function splitFileExt(filePath: string): string[] {
  const l: string[] = filePath.split('.');
  let ext: string | undefined = l.pop();
  if (!ext) {
    ext = '';
  }
  const name = l.join('.')
  return [ext, name]
}

export function getMimeTypeFromExtension(filePath: string): string {
  const extension = filePath.split('.').pop()?.toLowerCase() ?? '';

  const mimeMap: Record<string, string> = {
    'txt': 'text/plain',
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'mp3': 'audio/mpeg',
    'mp4': 'video/mp4',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'zip': 'application/zip',
    'rar': 'application/x-rar-compressed',
    'json': 'application/json',
    'html': 'text/html',
    'css': 'text/css',
    'js': 'text/javascript'
  };

  return mimeMap[extension] || 'application/octet-stream';
}

export function fileName(filePath: string): string {
  const l = filePath.split('/')
  const name = l.pop()
  if (!name) return filePath;
  return name;
}

export function base64Encode(str: string) {
  const base64 = new util.Base64Helper();
  const encoder = new util.TextEncoder()
  return base64.encodeToStringSync(encoder.encodeInto(str));
}

/**
 * 获取当前网络类型
 * @returns 返回网络类型字符串
 */
export async function getCurrentNetType(): Promise<connection.NetBearType> {
  try {
    const netHandle = await connection.getDefaultNet();
    const netCapabilities = await connection.getNetCapabilities(netHandle);
    return netCapabilities.bearerTypes[0];
  } catch (error) {
    console.error('获取网络类型失败:', (error as BusinessError).message);
    return connection.NetBearType.BEARER_WIFI;
  }
}

/**
 * 获取当前电池电量百分比
 * @returns 电量百分比(0-100)
 */
export function getBatteryLevel(): number {
  try {
    const batteryLevel = batteryInfo.batterySOC;
    // console.log(`当前电量: ${batteryLevel}%`);
    return batteryLevel;
  } catch (error) {
    console.error('获取电量失败:', (error as BusinessError).message);
    return -1; // 返回-1表示获取失败
  }
}

export function formatFileSize(size: number): string {
  if (size < 1024 * 1024) {
    // KB
    return (size / 1024).toFixed(2) + 'KB'
  }
  if (size >= 1024 * 1024 && size < 1024 * 1024 * 1024) {
    // MB
    return (size / 1024 / 1024).toFixed(2) + 'MB'
  }
  if (size >= 1024 * 1024 * 1024 && size < 1024 * 1024 * 1024 * 1024) {
    // GB
    return (size / 1024 / 1024 / 1024).toFixed(2) + 'GB'
  }
  // PB
  return (size / 1024 / 1024 / 1024 / 1024).toFixed(2) + 'PB'
}

export function fileSize(filePath: string): number {
  try {
    const stat = fileIo.statSync(filePath)
    return stat.size;
  } catch (e) {
    return -1;
  }

}