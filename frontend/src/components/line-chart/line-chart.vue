<template>
  <view class="line-chart">
    <view v-for="item in normalized" :key="item.label" class="bar-row">
      <text class="label">{{ item.label.slice(-5) }}</text>
      <view class="track">
        <view class="bar expense-bar" :style="{ width: `${item.expensePercent}%` }"></view>
        <view class="bar income-bar" :style="{ width: `${item.incomePercent}%` }"></view>
      </view>
      <text class="value">{{ item.balanceText }}</text>
    </view>
  </view>
</template>

<script setup>
import { computed } from 'vue'
import { formatMoney } from '../../utils/money'

const props = defineProps({
  data: {
    type: Array,
    default: () => []
  }
})

const maxValue = computed(() => {
  const values = props.data.flatMap((item) => [Number(item.income || 0), Number(item.expense || 0)])
  return Math.max(1, ...values)
})

const normalized = computed(() => props.data.map((item) => {
  const income = Number(item.income || 0)
  const expense = Number(item.expense || 0)
  return {
    label: item.label,
    incomePercent: Math.min(100, Math.round((income / maxValue.value) * 100)),
    expensePercent: Math.min(100, Math.round((expense / maxValue.value) * 100)),
    balanceText: formatMoney(Number(item.balance || 0))
  }
}))
</script>

<style scoped>
.line-chart {
  display: flex;
  flex-direction: column;
  gap: 14rpx;
  width: 100%;
  min-width: 0;
}

.bar-row {
  display: grid;
  grid-template-columns: 72rpx minmax(0, 1fr) 116rpx;
  align-items: center;
  gap: 12rpx;
  min-width: 0;
}

.label,
.value {
  color: #69746d;
  font-size: 22rpx;
}

.value {
  text-align: right;
  overflow: hidden;
  text-overflow: ellipsis;
}

.track {
  position: relative;
  height: 26rpx;
  border-radius: 8px;
  background: #eef3ef;
  overflow: hidden;
}

.bar {
  position: absolute;
  top: 0;
  bottom: 0;
  border-radius: 8px;
}

.expense-bar {
  left: 0;
  background: rgba(194, 65, 12, 0.72);
}

.income-bar {
  right: 0;
  background: rgba(22, 128, 60, 0.72);
}
</style>
