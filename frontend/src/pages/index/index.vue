<template>
  <view class="page">
    <view class="section title-row">
      <view>
        <text class="page-title">今日账本</text>
        <text class="muted block">连续记账 {{ dashboard.continuous_days || 0 }} 天</text>
      </view>
      <button class="small-btn" @click="refresh">刷新</button>
    </view>

    <view class="section grid-2">
      <view class="metric">
        <text class="metric-label">今日支出</text>
        <text class="metric-value expense">¥{{ money(dashboard.today_expense) }}</text>
      </view>
      <view class="metric">
        <text class="metric-label">今日收入</text>
        <text class="metric-value income">¥{{ money(dashboard.today_income) }}</text>
      </view>
      <view class="metric">
        <text class="metric-label">本月结余</text>
        <text class="metric-value">¥{{ money(dashboard.balance) }}</text>
      </view>
      <view class="metric">
        <text class="metric-label">预算使用</text>
        <text class="metric-value warn">{{ money(dashboard.budget_percent) }}%</text>
      </view>
    </view>

    <view class="section panel voice-panel">
      <view class="voice-copy">
        <text class="section-title">语音入账</text>
        <text class="muted block">说出一句账单，系统会识别成文字并交给 AI 入库</text>
      </view>

      <view class="voice-action">
        <button
          :class="['mic-button', recording ? 'is-recording' : '']"
          @click="toggleVoice"
        >
          <text class="mic-dot"></text>
          <text>{{ recording ? '停止' : '说话' }}</text>
        </button>
        <text class="voice-status">{{ voiceStatus }}</text>
      </view>

      <view class="transcript-card">
        <text class="transcript-label">识别文字</text>
        <text :class="['transcript-text', voiceDisplay ? '' : 'is-empty']">
          {{ voiceDisplay || '点击“说话”后，说出：今天中午吃麻辣烫花了25块' }}
        </text>
      </view>

      <view class="button-row no-bottom">
        <button
          class="btn btn-primary"
          :disabled="saving || !voiceDisplay"
          @click="submitVoiceBill"
        >
          {{ saving ? '正在入账' : 'AI识别并入账' }}
        </button>
        <button class="btn btn-secondary" :disabled="!voiceText && !lastRecord" @click="clearVoice">
          清空
        </button>
      </view>
    </view>

    <view v-if="lastRecord" class="section panel result-panel">
      <view class="title-row">
        <text class="section-title">本次入账</text>
        <button class="text-btn" @click="goStatistics">查看统计</button>
      </view>
      <view class="record-grid">
        <view class="record-item">
          <text class="record-label">金额</text>
          <text :class="['record-value', lastRecord.bill.bill_type === 'income' ? 'income' : 'expense']">
            ¥{{ money(lastRecord.bill.amount) }}
          </text>
        </view>
        <view class="record-item">
          <text class="record-label">分类</text>
          <text class="record-value">{{ lastRecord.bill.category?.name || '-' }}</text>
        </view>
        <view class="record-item">
          <text class="record-label">类型</text>
          <text class="record-value">{{ lastRecord.bill.bill_type === 'income' ? '收入' : '支出' }}</text>
        </view>
        <view class="record-item">
          <text class="record-label">备注</text>
          <text class="record-value">{{ lastRecord.bill.remark || lastRecord.parsed.remark }}</text>
        </view>
      </view>
    </view>

    <view class="section panel">
      <view class="title-row">
        <text class="section-title">最近账单</text>
        <button class="text-btn" @click="goBills">查看全部</button>
      </view>
      <view v-if="!dashboard.recent_bills?.length" class="empty">暂无账单</view>
      <bill-card
        v-for="bill in dashboard.recent_bills"
        :key="bill.id"
        :bill="bill"
        class="bill-gap"
        @edit="goBills"
        @delete="goBills"
      />
    </view>
  </view>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import BillCard from '../../components/bill-card/bill-card.vue'
import { recordBillText } from '../../api/ai'
import { getDashboard } from '../../api/statistics'
import { useUserStore } from '../../store/user'
import { formatMoney } from '../../utils/money'

const userStore = useUserStore()
const dashboard = ref({})
const voiceText = ref('')
const interimText = ref('')
const voiceStatus = ref('点击说话开始语音记账')
const recording = ref(false)
const saving = ref(false)
const voiceSupported = ref(false)
const lastRecord = ref(null)
let recognition = null

const voiceDisplay = computed(() => {
  return [voiceText.value, interimText.value].filter(Boolean).join(' ').trim()
})

function money(value) {
  return formatMoney(value)
}

function setupSpeechRecognition() {
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
    voiceStatus.value = voiceText.value ? '识别完成，可以入账' : '点击说话开始语音记账'
  }
}

function toggleVoice() {
  if (!voiceSupported.value || !recognition) {
    uni.showToast({ title: '当前环境不支持语音识别', icon: 'none' })
    return
  }
  if (recording.value) {
    recognition.stop()
    return
  }
  voiceText.value = ''
  interimText.value = ''
  try {
    recognition.start()
  } catch (error) {
    voiceStatus.value = '语音识别启动失败'
    uni.showToast({ title: error.message || '语音识别启动失败', icon: 'none' })
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
    lastRecord.value = await recordBillText(text)
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

function clearVoice() {
  voiceText.value = ''
  interimText.value = ''
  lastRecord.value = null
  voiceStatus.value = voiceSupported.value ? '点击说话开始语音记账' : '当前浏览器不支持语音识别'
}

function goBills() {
  uni.switchTab({ url: '/pages/bill/bill' })
}

function goStatistics() {
  uni.switchTab({ url: '/pages/statistics/statistics' })
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
.block {
  display: block;
  margin-top: 8rpx;
}

.section-title {
  display: block;
  min-width: 0;
  font-size: 30rpx;
  font-weight: 900;
  line-height: 1.3;
  word-break: break-word;
}

.warn {
  color: #b45309;
}

.small-btn,
.text-btn {
  flex: 0 0 auto;
  margin: 0;
  height: 58rpx;
  line-height: 58rpx;
  padding: 0 18rpx;
  border: 1rpx solid #dce4dd;
  border-radius: 8px;
  background: #fff;
  color: #15211a;
  font-size: 24rpx;
  white-space: nowrap;
}

.text-btn {
  border: 0;
  color: #1f6f78;
}

.voice-panel {
  display: flex;
  flex-direction: column;
  gap: 24rpx;
  background:
    linear-gradient(145deg, rgba(31, 111, 120, 0.12), transparent 42%),
    #fff;
}

.voice-copy {
  min-width: 0;
}

.voice-action {
  display: flex;
  align-items: center;
  gap: 22rpx;
  min-width: 0;
}

.mic-button {
  flex: 0 0 144rpx;
  width: 144rpx;
  height: 144rpx;
  margin: 0;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: #15211a;
  color: #fff;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8rpx;
  font-size: 24rpx;
  font-weight: 800;
  line-height: 1.2;
  box-shadow: 0 18rpx 40rpx rgba(21, 33, 26, 0.2);
}

.mic-button.is-recording {
  background: #c2410c;
}

.mic-dot {
  width: 34rpx;
  height: 50rpx;
  border-radius: 999rpx;
  border: 6rpx solid currentColor;
  display: block;
}

.voice-status {
  flex: 1 1 0;
  min-width: 0;
  color: #69746d;
  font-size: 26rpx;
  line-height: 1.45;
  word-break: break-word;
}

.transcript-card {
  border: 1rpx solid #dce4dd;
  border-radius: 8px;
  padding: 22rpx;
  background: #f8faf7;
}

.transcript-label,
.record-label {
  display: block;
  color: #69746d;
  font-size: 23rpx;
  line-height: 1.3;
}

.transcript-text {
  display: block;
  margin-top: 10rpx;
  color: #15211a;
  font-size: 30rpx;
  font-weight: 800;
  line-height: 1.45;
  word-break: break-word;
}

.transcript-text.is-empty {
  color: #8a948c;
  font-weight: 500;
}

.no-bottom {
  margin-top: 0;
}

.result-panel {
  border-color: rgba(22, 128, 60, 0.24);
}

.record-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16rpx;
  margin-top: 20rpx;
}

.record-item {
  min-width: 0;
  padding: 18rpx;
  border-radius: 8px;
  background: #eef3ef;
}

.record-value {
  display: block;
  margin-top: 8rpx;
  color: #15211a;
  font-size: 28rpx;
  font-weight: 800;
  line-height: 1.25;
  word-break: break-word;
}

.bill-gap {
  margin-top: 16rpx;
}
</style>
