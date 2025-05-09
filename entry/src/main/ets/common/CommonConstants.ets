/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * Common constants for all features.
 */
export class CommonConstants {

  /**
   * List space.
   */
  static readonly LIST_SPACE: string = '12vp';

  /**
   * Window util.
   */
  static readonly WINDOW_UTIL: string = 'windowUtil';

  /**
   * Full percent.
   */
  static readonly FULL_PERCENT: string = '100%';

  /**
   * Font weight 500.
   */
  static readonly FONT_WEIGHT_500: number = 500;

  /**
   * Font weight 700.
   */
  static readonly FONT_WEIGHT_700: number = 700;

  /**
   * Text opacity.
   */
  static readonly TEXT_OPACITY: number[] = [0.4, 0.5, 0.6, 1, 0.8];

  /**
   * Divider opacity.
   */
  static readonly DIVIDER_OPACITY: number = 0.05;

  /**
   * X component surface width.
   */
  static readonly X_COMPONENT_SURFACE_WIDTH: number = 1920;

  /**
   * X component surface height.
   */
  static readonly X_COMPONENT_SURFACE_HEIGHT: number = 1080;


  /**
   * Previous one row aspect ratio.
   */
  static readonly PREVIOUS_ONE_ROW_RATIO: number = 1.56;

  /**
   * Default window width.
   */
  static readonly DEFAULT_WINDOW_WIDTH: number = 320;

  /**
   * Device types.
   */
  static readonly DEVICE_TYPES: string[] = ['2in1', 'tablet', 'phone'];

  static readonly ANIMATION_DURATION = 300;
  static readonly PREFERENCES_NAME = "cyper-cloak-room";
}


