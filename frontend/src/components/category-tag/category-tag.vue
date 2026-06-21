<template>
  <view class="tag" :style="{ borderColor: color, color }">
    <text class="dot" :style="{ backgroundColor: color }"></text>
    <text>{{ name }}</text>
  </view>
</template>

<script setup>
defineProps({
  name: {
    type: String,
    default: '其他'
  },
  color: {
    type: String,
    default: '#6b7280'
  }
})
</script>

<style scoped>
.tag {
  display: inline-flex;
  align-items: center;
  gap: 8rpx;
  min-height: 48rpx;
  padding: 0 16rpx;
  border: 1rpx solid;
  border-radius: 8px;
  background: #fff;
  font-size: 24rpx;
  font-weight: 700;
}

.dot {
  width: 12rpx;
  height: 12rpx;
  border-radius: 50%;
}
</style>
