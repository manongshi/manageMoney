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

    <view class="section panel">
      <view class="title-row">
        <text class="section-title">快捷记账</text>
        <text class="muted">手动输入</text>
      </view>
      <view class="field">
        <view class="segmented">
          <view :class="['segment', form.bill_type === 'expense' ? 'active-expense' : '']" @click="switchType('expense')">支出</view>
          <view :class="['segment', form.bill_type === 'income' ? 'active-income' : '']" @click="switchType('income')">收入</view>
        </view>
      </view>
      <view class="field">
        <text class="field-label">金额</text>
        <input v-model="form.amount" class="input" type="digit" placeholder="0.00" />
      </view>
      <view class="field">
        <text class="field-label">分类</text>
        <picker :range="categoryNames" @change="onCategoryChange">
          <view class="picker-display">{{ selectedCategoryName || '请选择分类' }}</view>
        </picker>
      </view>
      <view class="field">
        <text class="field-label">备注</text>
        <input v-model="form.remark" class="input" placeholder="例如 午饭" />
      </view>
      <view class="button-row">
        <button class="btn btn-primary" @click="saveQuick">保存</button>
      </view>
    </view>

    <view class="section panel">
      <view class="title-row">
        <text class="section-title">AI文本记账</text>
        <text class="muted">语音识别结果可粘贴到这里</text>
      </view>
      <textarea v-model="aiText" class="textarea" placeholder="例如：今天中午吃麻辣烫花了25块" />
      <view class="button-row">
        <button class="btn btn-secondary" @click="parseAiText">解析到账单</button>
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
import { computed, reactive, ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import BillCard from '../../components/bill-card/bill-card.vue'
import { addBill } from '../../api/bill'
import { parseBillText } from '../../api/ai'
import { getDashboard } from '../../api/statistics'
import { useBillStore } from '../../store/bill'
import { useUserStore } from '../../store/user'
import { formatMoney } from '../../utils/money'

const userStore = useUserStore()
const billStore = useBillStore()
const dashboard = ref({})
const aiText = ref('')
const form = reactive({
  amount: '',
  category_id: '',
  bill_type: 'expense',
  remark: ''
})

const categories = computed(() => billStore.categories.filter((item) => item.type === form.bill_type))
const categoryNames = computed(() => categories.value.map((item) => item.name))
const selectedCategoryName = computed(() => categories.value.find((item) => item.id === form.category_id)?.name || '')

function money(value) {
  return formatMoney(value)
}

function switchType(type) {
  form.bill_type = type
  form.category_id = categories.value[0]?.id || ''
}

function onCategoryChange(event) {
  const index = Number(event.detail.value)
  form.category_id = categories.value[index]?.id || ''
}

async function refresh() {
  if (!userStore.token) {
    uni.redirectTo({ url: '/pages/login/login' })
    return
  }
  try {
    await Promise.all([userStore.loadProfile(), billStore.loadCategories()])
    if (!form.category_id) {
      form.category_id = categories.value[0]?.id || ''
    }
    dashboard.value = await getDashboard()
  } catch (error) {
    uni.showToast({ title: error.message, icon: 'none' })
  }
}

async function saveQuick() {
  if (!form.amount || !form.category_id) {
    uni.showToast({ title: '请填写金额和分类', icon: 'none' })
    return
  }
  try {
    await addBill({
      amount: Number(form.amount),
      category_id: form.category_id,
      bill_type: form.bill_type,
      remark: form.remark
    })
    form.amount = ''
    form.remark = ''
    await refresh()
    uni.showToast({ title: '已保存', icon: 'success' })
  } catch (error) {
    uni.showToast({ title: error.message, icon: 'none' })
  }
}

async function parseAiText() {
  if (!aiText.value.trim()) {
    uni.showToast({ title: '请输入一句记账文本', icon: 'none' })
    return
  }
  try {
    const parsed = await parseBillText(aiText.value)
    form.bill_type = parsed.bill_type
    await billStore.loadCategories()
    const match = categories.value.find((item) => item.name === parsed.category)
    form.category_id = match?.id || categories.value[0]?.id || ''
    form.amount = String(parsed.amount || '')
    form.remark = parsed.remark
    uni.showToast({ title: '已解析，请确认保存', icon: 'none' })
  } catch (error) {
    uni.showToast({ title: error.message, icon: 'none' })
  }
}

function goBills() {
  uni.switchTab({ url: '/pages/bill/bill' })
}

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

.bill-gap {
  margin-top: 16rpx;
}
</style>
