<template>
  <view class="bill-card">
    <view class="main">
      <view class="left">
        <category-tag
          :name="bill.category?.name || '其他'"
          :color="bill.category?.color || '#6b7280'"
        />
        <text class="remark">{{ bill.remark || '未填写备注' }}</text>
        <text class="time">{{ formatDateTime(bill.bill_time) }}</text>
      </view>
      <text :class="['amount', bill.bill_type === 'income' ? 'income' : 'expense']">
        {{ signedMoney(bill) }}
      </text>
    </view>
    <view class="actions">
      <button class="mini-btn" @click="$emit('edit', bill)">编辑</button>
      <button class="mini-btn danger" @click="$emit('delete', bill)">删除</button>
    </view>
  </view>
</template>

<script setup>
import CategoryTag from '../category-tag/category-tag.vue'
import { formatDateTime } from '../../utils/date'
import { signedMoney } from '../../utils/money'

defineProps({
  bill: {
    type: Object,
    required: true
  }
})

defineEmits(['edit', 'delete'])
</script>

<style scoped>
.bill-card {
  width: 100%;
  min-width: 0;
  padding: 22rpx;
  border: 1rpx solid #dce4dd;
  border-radius: 8px;
  background: #fff;
}

.main {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16rpx;
  min-width: 0;
}

.left {
  flex: 1 1 0;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 10rpx;
}

.remark {
  display: block;
  max-width: 100%;
  color: #15211a;
  font-size: 30rpx;
  font-weight: 800;
  line-height: 1.3;
  word-break: break-word;
}

.time {
  color: #69746d;
  font-size: 24rpx;
}

.amount {
  flex-shrink: 0;
  max-width: 230rpx;
  font-size: 32rpx;
  font-weight: 900;
  line-height: 1.25;
  text-align: right;
  word-break: break-word;
}

.income {
  color: #16803c;
}

.expense {
  color: #c2410c;
}

.actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 12rpx;
  margin-top: 18rpx;
}

.mini-btn {
  margin: 0;
  min-width: 104rpx;
  height: 58rpx;
  line-height: 58rpx;
  padding: 0 16rpx;
  border: 1rpx solid #dce4dd;
  border-radius: 8px;
  background: #fff;
  color: #15211a;
  font-size: 24rpx;
}

.danger {
  color: #c2410c;
  border-color: #fed7aa;
  background: #fff7ed;
}
</style>
