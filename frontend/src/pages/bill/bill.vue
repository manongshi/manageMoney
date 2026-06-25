<template>
  <view class="page bill-page">
    <view class="ledger-hero section">
      <view class="hero-copy">
        <text class="eyebrow">Gentle Ledger</text>
        <text class="page-title">账单</text>
        <text class="muted block">共 {{ billStore.total }} 条记录，保持清爽但不打扰</text>
      </view>
      <button class="primary-pill" @click="openCreate">补记</button>
    </view>

    <view class="section summary-strip">
      <view>
        <text class="metric-label">本页支出</text>
        <text class="summary-value expense">¥{{ money(pageExpense) }}</text>
      </view>
      <view>
        <text class="metric-label">本页收入</text>
        <text class="summary-value income">¥{{ money(pageIncome) }}</text>
      </view>
    </view>

    <view class="section panel filter-panel">
      <view class="search-box">
        <text class="search-mark"></text>
        <input v-model="filters.keyword" class="search-input" placeholder="搜索备注或分类" @confirm="loadBills" />
      </view>
      <view class="filter-row">
        <picker :range="typeNames" @change="onTypeFilterChange">
          <view class="filter-chip">{{ currentTypeName }}</view>
        </picker>
        <picker :range="categoryFilterNames" @change="onCategoryFilterChange">
          <view class="filter-chip">{{ currentCategoryName }}</view>
        </picker>
        <button class="filter-chip search-chip" @click="loadBills">筛选</button>
      </view>
    </view>

    <view v-if="showForm" class="section panel edit-panel">
      <view class="title-row">
        <text class="section-title">{{ editingId ? '调整账单' : '补记一笔' }}</text>
        <button class="text-btn" @click="closeForm">收起</button>
      </view>
      <view class="field">
        <view class="segmented soft-segmented">
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
        <picker :range="formCategoryNames" @change="onFormCategoryChange">
          <view class="picker-display">{{ formCategoryName || '请选择分类' }}</view>
        </picker>
      </view>
      <view class="field">
        <text class="field-label">备注</text>
        <input v-model="form.remark" class="input" placeholder="例如：咖啡、通勤、礼物" />
      </view>
      <view class="button-row">
        <button class="btn btn-primary" @click="submitBill">保存</button>
        <button class="btn btn-secondary" @click="closeForm">取消</button>
      </view>
    </view>

    <view class="section list-section">
      <view class="list-title-row">
        <text class="section-title">消费明细</text>
        <text class="muted">{{ billStore.bills.length }} 条</text>
      </view>
      <view v-if="!billStore.bills.length" class="empty soft-empty">暂无账单</view>
      <bill-card
        v-for="bill in billStore.bills"
        :key="bill.id"
        :bill="bill"
        class="bill-gap"
        @edit="openEdit"
        @delete="confirmDelete"
      />
    </view>
  </view>
</template>

<script setup>
import { computed, reactive, ref } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import BillCard from '../../components/bill-card/bill-card.vue'
import { addBill, deleteBill, updateBill } from '../../api/bill'
import { useBillStore } from '../../store/bill'
import { useUserStore } from '../../store/user'
import { formatMoney } from '../../utils/money'

const userStore = useUserStore()
const billStore = useBillStore()
const showForm = ref(false)
const editingId = ref('')
const filters = reactive({
  keyword: '',
  bill_type: '',
  category_id: ''
})
const form = reactive({
  amount: '',
  category_id: '',
  bill_type: 'expense',
  remark: ''
})

const typeNames = ['全部', '支出', '收入']
const currentTypeName = computed(() => ({ expense: '支出', income: '收入' }[filters.bill_type] || '全部类型'))
const filterCategories = computed(() => {
  return filters.bill_type
    ? billStore.categories.filter((item) => item.type === filters.bill_type)
    : billStore.categories
})
const categoryFilterNames = computed(() => ['全部分类', ...filterCategories.value.map((item) => item.name)])
const currentCategoryName = computed(() => {
  if (!filters.category_id) return '全部分类'
  return filterCategories.value.find((item) => item.id === filters.category_id)?.name || '全部分类'
})
const formCategories = computed(() => billStore.categories.filter((item) => item.type === form.bill_type))
const formCategoryNames = computed(() => formCategories.value.map((item) => item.name))
const formCategoryName = computed(() => formCategories.value.find((item) => item.id === form.category_id)?.name || '')
const pageExpense = computed(() => {
  return billStore.bills
    .filter((item) => item.bill_type === 'expense')
    .reduce((sum, item) => sum + Number(item.amount || 0), 0)
})
const pageIncome = computed(() => {
  return billStore.bills
    .filter((item) => item.bill_type === 'income')
    .reduce((sum, item) => sum + Number(item.amount || 0), 0)
})

function money(value) {
  return formatMoney(value)
}

function requireLogin() {
  if (!userStore.token) {
    uni.redirectTo({ url: '/pages/login/login' })
    return false
  }
  return true
}

async function loadBills() {
  if (!requireLogin()) return
  try {
    await billStore.loadCategories()
    await billStore.loadBills({
      keyword: filters.keyword,
      bill_type: filters.bill_type,
      category_id: filters.category_id,
      page_size: 50
    })
  } catch (error) {
    uni.showToast({ title: error.message, icon: 'none' })
  }
}

function onTypeFilterChange(event) {
  const value = Number(event.detail.value)
  filters.bill_type = value === 1 ? 'expense' : value === 2 ? 'income' : ''
  filters.category_id = ''
  loadBills()
}

function onCategoryFilterChange(event) {
  const index = Number(event.detail.value)
  filters.category_id = index === 0 ? '' : filterCategories.value[index - 1]?.id || ''
  loadBills()
}

function onFormCategoryChange(event) {
  const index = Number(event.detail.value)
  form.category_id = formCategories.value[index]?.id || ''
}

function switchType(type) {
  form.bill_type = type
  form.category_id = formCategories.value[0]?.id || ''
}

function openCreate() {
  editingId.value = ''
  form.amount = ''
  form.remark = ''
  form.bill_type = 'expense'
  form.category_id = formCategories.value[0]?.id || ''
  showForm.value = true
}

function openEdit(bill) {
  editingId.value = bill.id
  form.amount = String(bill.amount)
  form.category_id = bill.category_id
  form.bill_type = bill.bill_type
  form.remark = bill.remark || ''
  showForm.value = true
}

function closeForm() {
  showForm.value = false
}

async function submitBill() {
  if (!form.amount || !form.category_id) {
    uni.showToast({ title: '请填写金额和分类', icon: 'none' })
    return
  }
  const payload = {
    amount: Number(form.amount),
    category_id: form.category_id,
    bill_type: form.bill_type,
    remark: form.remark
  }
  try {
    if (editingId.value) {
      await updateBill(editingId.value, payload)
    } else {
      await addBill(payload)
    }
    showForm.value = false
    await loadBills()
    uni.showToast({ title: '已保存', icon: 'success' })
  } catch (error) {
    uni.showToast({ title: error.message, icon: 'none' })
  }
}

function confirmDelete(bill) {
  uni.showModal({
    title: '删除账单',
    content: `确认删除「${bill.remark || bill.category?.name || '账单'}」？`,
    success: async (res) => {
      if (!res.confirm) return
      try {
        await deleteBill(bill.id)
        await loadBills()
      } catch (error) {
        uni.showToast({ title: error.message, icon: 'none' })
      }
    }
  })
}

onShow(loadBills)
</script>

<style scoped>
.bill-page {
  background:
    radial-gradient(circle at 18% 4%, rgba(213, 159, 145, 0.26), transparent 32%),
    radial-gradient(circle at 100% 20%, rgba(119, 153, 130, 0.16), transparent 30%);
}

.block {
  display: block;
  margin-top: 8rpx;
}

.ledger-hero {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 20rpx;
  padding-top: 18rpx;
}

.hero-copy {
  min-width: 0;
}

.eyebrow {
  display: block;
  margin-bottom: 10rpx;
  color: #a76658;
  font-size: 22rpx;
  font-weight: 800;
  letter-spacing: 0;
}

.primary-pill {
  flex: 0 0 auto;
  margin: 0;
  height: 70rpx;
  line-height: 70rpx;
  padding: 0 26rpx;
  border: 0;
  border-radius: 8px;
  background: linear-gradient(135deg, #8f4f43, #c68475);
  color: #fff;
  font-size: 26rpx;
  font-weight: 800;
  box-shadow: 0 14rpx 34rpx rgba(143, 79, 67, 0.22);
}

.summary-strip {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16rpx;
}

.summary-strip > view {
  min-width: 0;
  padding: 24rpx;
  border: 1rpx solid rgba(234, 219, 212, 0.82);
  border-radius: 8px;
  background: rgba(255, 253, 251, 0.84);
  box-shadow: 0 12rpx 32rpx rgba(86, 54, 43, 0.06);
}

.summary-value {
  display: block;
  margin-top: 8rpx;
  font-size: 34rpx;
  font-weight: 900;
  line-height: 1.16;
  word-break: break-word;
}

.filter-panel,
.edit-panel {
  border-color: rgba(216, 188, 177, 0.86);
  background: rgba(255, 253, 251, 0.92);
}

.search-box {
  display: flex;
  align-items: center;
  min-height: 78rpx;
  padding: 0 20rpx;
  border: 1rpx solid #eadbd4;
  border-radius: 8px;
  background: #fff8f5;
}

.search-mark {
  display: block;
  flex: 0 0 auto;
  width: 22rpx;
  height: 22rpx;
  margin-right: 14rpx;
  border: 4rpx solid #a76658;
  border-radius: 50%;
  position: relative;
}

.search-mark::after {
  position: absolute;
  right: -9rpx;
  bottom: -8rpx;
  width: 12rpx;
  height: 4rpx;
  border-radius: 999rpx;
  background: #a76658;
  transform: rotate(45deg);
  content: "";
}

.search-input {
  flex: 1 1 0;
  min-width: 0;
  color: #332522;
  font-size: 28rpx;
}

.filter-row {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
  margin-top: 16rpx;
  overflow: visible;
}

.filter-chip,
.text-btn {
  flex: 0 0 auto;
  margin: 0;
  height: 60rpx;
  line-height: 60rpx;
  padding: 0 20rpx;
  border: 1rpx solid #eadbd4;
  border-radius: 8px;
  background: #fffdfb;
  color: #6f5048;
  font-size: 24rpx;
  white-space: nowrap;
}

.search-chip {
  color: #8f4f43;
  font-weight: 800;
}

.text-btn {
  border: 0;
  color: #a76658;
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

.soft-segmented {
  border-color: #eadbd4;
  background: #fff8f5;
}

.list-section {
  margin-bottom: 10rpx;
}

.list-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16rpx;
  margin-bottom: 16rpx;
}

.soft-empty {
  border: 1rpx dashed #d8bcb1;
  border-radius: 8px;
  background: rgba(255, 253, 251, 0.7);
}

.bill-gap {
  margin-bottom: 16rpx;
}

:deep(.bill-card) {
  border-color: rgba(234, 219, 212, 0.9);
  background: rgba(255, 253, 251, 0.94);
  box-shadow: 0 14rpx 34rpx rgba(86, 54, 43, 0.06);
}
</style>
