import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

export async function checkPermissionGrant(permission: Permissions): Promise<abilityAccessCtrl.GrantStatus> {
  let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  let grantStatus: abilityAccessCtrl.GrantStatus = abilityAccessCtrl.GrantStatus.PERMISSION_DENIED;

  // 获取应用程序的accessTokenID
  let tokenId: number = 0;
  try {
    let bundleInfo: bundleManager.BundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
    let appInfo: bundleManager.ApplicationInfo = bundleInfo.appInfo;
    tokenId = appInfo.accessTokenId;
  } catch (error) {
    const err: BusinessError = error as BusinessError;
    console.error(`Failed to get bundle info for self. Code is ${err.code}, message is ${err.message}`);
  }

  // 校验应用是否被授予权限
  try {
    grantStatus = await atManager.checkAccessToken(tokenId, permission);
  } catch (error) {
    const err: BusinessError = error as BusinessError;
    console.error(`Failed to check access token. Code is ${err.code}, message is ${err.message}`);
  }

  return grantStatus;
}

export async function checkPermissions(context: common.UIAbilityContext, p: Permissions[]): Promise<boolean> {
  let waitReqPermissions: Permissions[] = []
  for (let i=0; i<p.length; i++) {
    let grantStatus1: boolean = await checkPermissionGrant(p[i]) === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    if (!grantStatus1) {
      waitReqPermissions.push(p[i])
    }
  }
  // 精确定位权限只能跟模糊定位权限一起申请，或者已经有模糊定位权限才能申请精确定位权限
  if (waitReqPermissions.length > 0) {
    return await reqPermissionsFromUser(context, waitReqPermissions)
  }
  return true
}
// 'ohos.permission.READ_IMAGEVIDEO'
export async function reqPermissionsFromUser(context: common.UIAbilityContext, p: Permissions[]) {
  let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  // requestPermissionsFromUser会判断权限的授权状态来决定是否唤起弹窗
  try {
    const data = await atManager.requestPermissionsFromUser(context, p);
    let grantStatus: Array<number> = data.authResults;
    let length: number = grantStatus.length;
    for (let i = 0; i < length; i++) {
      if (grantStatus[i] !== 0) {
        // 用户拒绝授权，提示用户必须授权才能访问当前页面的功能，并引导用户到系统设置中打开相应的权限
        // IBestToast.show("没有相册读取权限无法完成备份工作，请到'设置 > 应用和元服务 > 相册备份'中打开'图片和视频 -> 仅读取'权限后再重新打开本应用")
        return false
      }
    }
    // 授权成功
    return true
  } catch(err) {
    console.error(`Failed to request permissions from user. Code is ${err.code}, message is ${err.message}`);
    return false
  }
}