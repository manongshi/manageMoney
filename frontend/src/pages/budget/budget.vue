<template>
  <view class="page">
    <view class="section title-row">
      <view>
        <text class="page-title">预算</text>
        <text class="muted block">{{ month }} 月预算状态</text>
      </view>
      <button class="small-btn" @click="loadInfo">刷新</button>
    </view>

    <view class="section panel budget-card">
      <text class="metric-label">预算使用率</text>
      <text class="budget-percent">{{ money(info.percent) }}%</text>
      <view class="progress">
        <view class="progress-bar" :style="{ width: `${progressWidth}%` }"></view>
      </view>
      <view class="budget-row">
        <view>
          <text class="muted">已消费</text>
          <text class="budget-number expense">¥{{ money(info.spent) }}</text>
        </view>
        <view>
          <text class="muted">剩余</text>
          <text class="budget-number income">¥{{ money(info.remaining) }}</text>
        </view>
      </view>
      <view v-if="info.over_budget" class="alert">已超过本月预算</view>
    </view>

    <view class="section panel">
      <view class="field no-top">
        <text class="field-label">月份</text>
        <input v-model="month" class="input" placeholder="YYYY-MM" />
      </view>
      <view class="field">
        <text class="field-label">月预算</text>
        <input v-model="amount" class="input" type="digit" placeholder="3000" />
      </view>
      <view class="button-row">
        <button class="btn btn-primary" @click="save">保存预算</button>
      </view>
    </view>
  </view>
</template>

<script setup>
import { computed, ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { getBudgetInfo, saveBudget } from '../../api/budget'
import { currentMonth } from '../../utils/date'
import { formatMoney } from '../../utils/money'
import { useUserStore } from '../../store/user'

const userStore = useUserStore()
const month = ref(currentMonth())
const amount = ref('')
const info = ref({
  month_budget: 0,
  spent: 0,
  remaining: 0,
  percent: 0,
  over_budget: false
})

const progressWidth = computed(() => Math.min(100, Number(info.value.percent || 0)))

function money(value) {
  return formatMoney(value)
}

async function loadInfo() {
  if (!userStore.token) {
    uni.redirectTo({ url: '/pages/login/login' })
    return
  }
  try {
    info.value = await getBudgetInfo(month.value)
    amount.value = String(info.value.month_budget || '')
  } catch (error) {
    uni.showToast({ title: error.message, icon: 'none' })
  }
}

async function save() {
  if (!amount.value) {
    uni.showToast({ title: '请填写预算金额', icon: 'none' })
    return
  }
  try {
    info.value = await saveBudget({
      month: month.value,
      month_budget: Number(amount.value)
    })
    uni.showToast({ title: '已保存', icon: 'success' })
  } catch (error) {
    uni.showToast({ title: error.message, icon: 'none' })
  }
}

onShow(loadInfo)
</script>

<style scoped>
.block {
  display: block;
  margin-top: 8rpx;
}

.small-btn {
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

.budget-card {
  display: flex;
  flex-direction: column;
  gap: 18rpx;
}

.budget-percent {
  max-width: 100%;
  font-size: 68rpx;
  font-weight: 900;
  color: #15211a;
  line-height: 1.1;
  word-break: break-word;
}

.progress {
  height: 30rpx;
  border-radius: 8px;
  background: #eef3ef;
  overflow: hidden;
}

.progress-bar {
  height: 100%;
  border-radius: 8px;
  background: linear-gradient(90deg, #16803c, #b45309);
}

.budget-row {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 24rpx;
}

.budget-row > view {
  flex: 1 1 240rpx;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 8rpx;
}

.budget-number {
  font-size: 34rpx;
  font-weight: 900;
  line-height: 1.25;
  word-break: break-word;
}

.alert {
  padding: 16rpx;
  border-radius: 8px;
  background: #fff7ed;
  color: #c2410c;
  font-size: 26rpx;
  font-weight: 800;
  line-height: 1.35;
}

.no-top {
  margin-top: 0;
}
</style>
