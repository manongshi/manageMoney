<template>
  <view class="chart-wrap">
    <view class="pie" :style="{ background: gradient }">
      <view class="pie-hole">
        <text class="pie-total">¥{{ totalText }}</text>
        <text class="pie-label">分类</text>
      </view>
    </view>
    <view class="legend">
      <view v-for="(item, index) in normalized" :key="item.name" class="legend-item">
        <text class="legend-dot" :style="{ backgroundColor: colors[index % colors.length] }"></text>
        <text class="legend-name">{{ item.name }}</text>
        <text class="legend-value">¥{{ item.value.toFixed(2) }}</text>
      </view>
    </view>
  </view>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  data: {
    type: Array,
    default: () => []
  }
})

const colors = ['#c2410c', '#1f6f78', '#16803c', '#b45309', '#3b82f6', '#64748b']

const normalized = computed(() => props.data.map((item) => ({
  name: item.name,
  value: Number(item.value || 0)
})))

const total = computed(() => normalized.value.reduce((sum, item) => sum + item.value, 0))
const totalText = computed(() => total.value.toFixed(2))

const gradient = computed(() => {
  if (!normalized.value.length || total.value <= 0) {
    return '#eef3ef'
  }
  let start = 0
  const parts = normalized.value.map((item, index) => {
    const end = start + (item.value / total.value) * 100
    const part = `${colors[index % colors.length]} ${start}% ${end}%`
    start = end
    return part
  })
  return `conic-gradient(${parts.join(',')})`
})
</script>

<style scoped>
.chart-wrap {
  display: flex;
  flex-wrap: wrap;
  gap: 22rpx;
  align-items: center;
  justify-content: center;
  width: 100%;
  min-width: 0;
}

.pie {
  flex: 0 0 auto;
  width: 240rpx;
  height: 240rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.pie-hole {
  width: 142rpx;
  height: 142rpx;
  border-radius: 50%;
  background: #fff;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.pie-total {
  max-width: 128rpx;
  overflow: hidden;
  text-overflow: ellipsis;
  color: #15211a;
  font-size: 24rpx;
  font-weight: 900;
}

.pie-label {
  color: #69746d;
  font-size: 22rpx;
}

.legend {
  flex: 1 1 280rpx;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 12rpx;
}

.legend-item {
  display: grid;
  grid-template-columns: 18rpx minmax(0, 1fr) auto;
  gap: 10rpx;
  align-items: center;
  color: #15211a;
  font-size: 24rpx;
}

.legend-dot {
  width: 16rpx;
  height: 16rpx;
  border-radius: 50%;
}

.legend-name {
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.legend-value {
  color: #69746d;
  white-space: nowrap;
}
</style>
