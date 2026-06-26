<template>
  <view class="page voice-home">
    <view class="home-hero section">
      <view>
        <text class="eyebrow">Voice Ledger</text>
        <text class="page-title">今日账本</text>
        <text class="muted block">说一句消费，自动整理成账单</text>
      </view>
      <button class="small-btn refresh-btn" @click="refresh">刷新</button>
    </view>

    <view class="section balance-panel">
      <text class="metric-label">本月结余</text>
      <text class="balance-value">¥{{ money(dashboard.balance) }}</text>
      <view class="balance-meta">
        <text>本月收入 ¥{{ money(dashboard.month_income) }}</text>
        <text>本月支出 ¥{{ money(dashboard.month_expense) }}</text>
      </view>
    </view>

    <view class="section grid-2">
      <view class="metric soft-metric">
        <text class="metric-label">今日支出</text>
        <text class="metric-value expense">¥{{ money(dashboard.today_expense) }}</text>
      </view>
      <view class="metric soft-metric">
        <text class="metric-label">今日收入</text>
        <text class="metric-value income">¥{{ money(dashboard.today_income) }}</text>
      </view>
      <view class="metric soft-metric">
        <text class="metric-label">连续记账</text>
        <text class="metric-value">{{ dashboard.continuous_days || 0 }} 天</text>
      </view>
      <view class="metric soft-metric">
        <text class="metric-label">本月支出</text>
        <text class="metric-value expense">¥{{ money(dashboard.month_expense) }}</text>
      </view>
    </view>

    <view class="section hint-panel">
      <text class="section-title">一句话就够了</text>
      <text class="muted block">例如：今天买咖啡花了 19 元、工资到账 8000 元。</text>
    </view>

    <view class="voice-dock">
      <view class="transcript-bar">
        <text :class="['transcript-text', voiceDisplay ? '' : 'is-empty']">
          {{ voiceDisplay || voiceStatus }}
        </text>
      </view>

      <view class="dock-row">
        <button
          :class="['hold-button', recording ? 'is-recording' : '']"
          @touchstart.prevent="startVoice"
          @touchend.prevent="stopVoice"
          @mousedown.prevent="startVoice"
          @mouseup.prevent="stopVoice"
          @mouseleave="stopVoice"
          @click="handleVoiceClick"
        >
          <text>{{ recording ? '松开结束' : '按住说话' }}</text>
        </button>
        <button
          class="send-button"
          :disabled="saving || !voiceDisplay"
          @click="submitVoiceBill"
        >
          {{ saving ? '入账中' : '整理入账' }}
        </button>
      </view>
    </view>
  </view>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { recordBillText } from '../../api/ai'
import { getDashboard } from '../../api/statistics'
import { useUserStore } from '../../store/user'
import { formatMoney } from '../../utils/money'

const userStore = useUserStore()
const dashboard = ref({})
const voiceText = ref('')
const interimText = ref('')
const voiceStatus = ref('按住下方按钮开始语音记账')
const recording = ref(false)
const saving = ref(false)
const voiceSupported = ref(false)
let recognition = null
let lastTouchAt = 0
let manualStopPending = false

const voiceDisplay = computed(() => {
  return [voiceText.value, interimText.value].filter(Boolean).join(' ').trim()
})

function money(value) {
  return formatMoney(value)
}

function setupSpeechRecognition() {
  // #ifdef APP-PLUS
  setupAppSpeechRecognition()
  // #endif

  // #ifndef APP-PLUS
  setupWebSpeechRecognition()
  // #endif
}

function appendVoiceText(text) {
  const normalized = `${text || ''}`.trim()
  if (!normalized) return
  const current = voiceText.value.trim()
  if (!current || normalized.startsWith(current)) {
    voiceText.value = normalized
    return
  }
  if (!current.endsWith(normalized)) {
    voiceText.value = `${current}${normalized}`
  }
}

function finishRecognitionStatus() {
  recording.value = false
  interimText.value = ''
  voiceStatus.value = voiceText.value ? '识别完成，可以入账' : '按住下方按钮开始语音记账'
}

function setupAppSpeechRecognition() {
  runWhenPlusReady(() => {
    if (typeof plus === 'undefined' || !plus.speech) {
      voiceStatus.value = 'App 未启用语音模块，请重新打包'
      voiceSupported.value = false
      return
    }

    plus.speech.addEventListener('start', () => {
      recording.value = true
      manualStopPending = false
      interimText.value = ''
      voiceStatus.value = '正在听你说账单'
    }, false)

    plus.speech.addEventListener('recognizing', (event) => {
      interimText.value = `${event && event.partialResult ? event.partialResult : ''}`.trim()
    }, false)

    plus.speech.addEventListener('recognition', (event) => {
      appendVoiceText(event && event.result)
      interimText.value = ''
    }, false)

    plus.speech.addEventListener('end', () => {
      manualStopPending = false
      finishRecognitionStatus()
    }, false)

    recognition = {
      start() {
        manualStopPending = false
        recording.value = true
        interimText.value = ''
        voiceStatus.value = '正在听你说账单'
        plus.speech.startRecognize({
          lang: 'zh-cn',
          userInterface: false,
          continue: true
        }, (text) => {
          appendVoiceText(text)
        }, (error) => {
          handleAppSpeechError(error)
        })
      },
      stop() {
        manualStopPending = true
        plus.speech.stopRecognize()
      }
    }
    voiceSupported.value = true
    voiceStatus.value = '按住下方按钮开始语音记账'
  })
}

function runWhenPlusReady(callback) {
  if (typeof plus !== 'undefined') {
    callback()
    return
  }
  if (typeof document !== 'undefined') {
    document.addEventListener('plusready', callback, false)
    return
  }
  voiceStatus.value = 'App 语音模块初始化失败'
}

function handleAppSpeechError(error) {
  const message = `${(error && (error.message || error.code)) || ''}`.trim()
  recording.value = false
  interimText.value = ''
  if (manualStopPending && voiceText.value) {
    manualStopPending = false
    voiceStatus.value = '识别完成，可以入账'
    return
  }
  manualStopPending = false
  if (!message) {
    voiceStatus.value = '语音识别失败，请重试'
    return
  }
  voiceStatus.value = /permission|denied|auth|record/i.test(message)
    ? '麦克风权限或语音服务未开启'
    : `语音识别失败：${message}`
}

function setupWebSpeechRecognition() {
  if (typeof window === 'undefined') {
    voiceStatus.value = '当前环境不支持语音识别'
    return
  }
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
  if (!SpeechRecognition) {
    voiceStatus.value = '当前浏览器不支持语音识别'
    return
  }

  recognition = new SpeechRecognition()
  recognition.lang = 'zh-CN'
  recognition.continuous = false
  recognition.interimResults = true
  voiceSupported.value = true

  recognition.onstart = () => {
    recording.value = true
    interimText.value = ''
    voiceStatus.value = '正在听你说账单'
  }
  recognition.onresult = (event) => {
    let finalText = ''
    let pendingText = ''
    for (let index = 0; index < event.results.length; index += 1) {
      const text = event.results[index][0].transcript.trim()
      if (event.results[index].isFinal) {
        finalText += text
      } else {
        pendingText += text
      }
    }
    if (finalText) {
      voiceText.value = finalText
    }
    interimText.value = pendingText
  }
  recognition.onerror = (event) => {
    recording.value = false
    voiceStatus.value = event.error === 'not-allowed' ? '麦克风权限未开启' : '语音识别失败，请重试'
  }
  recognition.onend = () => {
    recording.value = false
    interimText.value = ''
    voiceStatus.value = voiceText.value ? '识别完成，可以入账' : '按住下方按钮开始语音记账'
  }
}

function startVoice() {
  if (!voiceSupported.value || !recognition) {
    uni.showToast({ title: '当前环境不支持语音识别', icon: 'none' })
    return
  }
  if (recording.value) return
  voiceText.value = ''
  interimText.value = ''
  try {
    recognition.start()
  } catch (error) {
    recording.value = false
    manualStopPending = false
    voiceStatus.value = '语音识别启动失败'
    uni.showToast({ title: error.message || '语音识别启动失败', icon: 'none' })
  }
}

function stopVoice() {
  lastTouchAt = Date.now()
  if (recognition && recording.value) {
    try {
      recognition.stop()
    } catch (error) {
      recording.value = false
      manualStopPending = false
      voiceStatus.value = '语音识别停止失败'
    }
  }
}

function handleVoiceClick() {
  if (Date.now() - lastTouchAt < 500) return
  if (recording.value) {
    stopVoice()
  } else {
    startVoice()
  }
}

async function refresh() {
  if (!userStore.token) {
    uni.redirectTo({ url: '/pages/login/login' })
    return
  }
  try {
    await userStore.loadProfile()
    dashboard.value = await getDashboard()
  } catch (error) {
    uni.showToast({ title: error.message, icon: 'none' })
  }
}

async function submitVoiceBill() {
  const text = voiceDisplay.value
  if (!text) {
    uni.showToast({ title: '请先完成语音识别', icon: 'none' })
    return
  }
  saving.value = true
  try {
    await recordBillText(text)
    voiceText.value = ''
    interimText.value = ''
    voiceStatus.value = '已入账，统计已更新'
    await refresh()
    uni.showToast({ title: '已入账', icon: 'success' })
  } catch (error) {
    uni.showToast({ title: error.message, icon: 'none' })
  } finally {
    saving.value = false
  }
}

onMounted(setupSpeechRecognition)
onBeforeUnmount(() => {
  if (recognition && recording.value) {
    recognition.stop()
  }
})
onShow(refresh)
</script>

<style scoped>
.voice-home {
  min-height: 100vh;
  padding-bottom: calc(344rpx + env(safe-area-inset-bottom));
}

.block {
  display: block;
  margin-top: 8rpx;
}

.home-hero {
  display: flex;
  justify-content: space-between;
  gap: 20rpx;
  min-width: 0;
  padding: 22rpx 0 4rpx;
}

.eyebrow {
  display: block;
  margin-bottom: 10rpx;
  color: #a76658;
  font-size: 22rpx;
  font-weight: 800;
  letter-spacing: 0;
}

.refresh-btn {
  align-self: flex-start;
}

.balance-panel {
  padding: 34rpx 30rpx;
  border: 1rpx solid rgba(202, 150, 136, 0.36);
  border-radius: 8px;
  background:
    linear-gradient(140deg, rgba(196, 132, 115, 0.2), transparent 38%),
    linear-gradient(320deg, rgba(231, 207, 191, 0.75), rgba(255, 253, 251, 0.96));
  box-shadow: 0 22rpx 56rpx rgba(122, 73, 59, 0.1);
}

.balance-value {
  display: block;
  margin-top: 12rpx;
  color: #332522;
  font-size: 56rpx;
  font-weight: 900;
  line-height: 1.1;
}

.balance-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 14rpx;
  margin-top: 24rpx;
  color: #7f665e;
  font-size: 24rpx;
  line-height: 1.35;
}

.soft-metric {
  border: 1rpx solid rgba(234, 219, 212, 0.9);
  background: rgba(255, 253, 251, 0.84);
}

.hint-panel {
  padding: 26rpx;
  border: 1rpx dashed #d8bcb1;
  border-radius: 8px;
  background: rgba(255, 253, 251, 0.68);
}

.section-title {
  display: block;
  min-width: 0;
  color: #332522;
  font-size: 30rpx;
  font-weight: 900;
  line-height: 1.3;
  word-break: break-word;
}

.small-btn {
  flex: 0 0 auto;
  margin: 0;
  height: 58rpx;
  line-height: 58rpx;
  padding: 0 20rpx;
  border: 1rpx solid #eadbd4;
  border-radius: 8px;
  background: #fffdfb;
  color: #6f5048;
  font-size: 24rpx;
  white-space: nowrap;
}

.voice-dock {
  position: fixed;
  right: 0;
  bottom: calc(98rpx + env(safe-area-inset-bottom));
  left: 0;
  z-index: 30;
  width: 100%;
  max-width: 750rpx;
  margin: 0 auto;
  padding: 18rpx 22rpx;
  border-top: 1rpx solid rgba(216, 188, 177, 0.72);
  background: rgba(255, 253, 251, 0.96);
  box-shadow: 0 -18rpx 48rpx rgba(86, 54, 43, 0.1);
  box-sizing: border-box;
}

.transcript-bar {
  min-height: 62rpx;
  padding: 16rpx 20rpx;
  border-radius: 8px;
  background: #f8eee9;
}

.transcript-text {
  display: block;
  color: #332522;
  font-size: 27rpx;
  font-weight: 700;
  line-height: 1.45;
  word-break: break-word;
}

.transcript-text.is-empty {
  color: #8a736b;
  font-weight: 500;
}

.dock-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
  margin-top: 16rpx;
}

.hold-button,
.send-button {
  margin: 0;
  min-height: 82rpx;
  border-radius: 8px;
  border: 1rpx solid transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10rpx;
  font-size: 28rpx;
  font-weight: 800;
  line-height: 1.2;
}

.hold-button {
  flex: 1 1 auto;
  background: #fff8f5;
  border-color: #dcc4ba;
  color: #332522;
}

.hold-button.is-recording {
  background: #fff0eb;
  border-color: #c68475;
  color: #8f4f43;
}

.send-button {
  flex: 0 0 184rpx;
  background: linear-gradient(135deg, #8f4f43, #c68475);
  color: #fff;
  box-shadow: 0 12rpx 28rpx rgba(143, 79, 67, 0.22);
}

.send-button[disabled] {
  opacity: 0.48;
  box-shadow: none;
}

</style>
