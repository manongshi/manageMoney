<template>
  <view class="page">
    <view class="section title-row">
      <view>
        <text class="page-title">账单</text>
        <text class="muted block">共 {{ billStore.total }} 条记录</text>
      </view>
      <button class="small-btn" @click="openCreate">新增</button>
    </view>

    <view class="section panel">
      <view class="field no-top">
        <input v-model="filters.keyword" class="input" placeholder="搜索备注或分类" @confirm="loadBills" />
      </view>
      <view class="filter-row">
        <picker :range="typeNames" @change="onTypeFilterChange">
          <view class="filter-chip">{{ currentTypeName }}</view>
        </picker>
        <picker :range="categoryFilterNames" @change="onCategoryFilterChange">
          <view class="filter-chip">{{ currentCategoryName }}</view>
        </picker>
        <button class="filter-chip" @click="loadBills">搜索</button>
      </view>
    </view>

    <view v-if="showForm" class="section panel">
      <view class="title-row">
        <text class="section-title">{{ editingId ? '编辑账单' : '新增账单' }}</text>
        <button class="text-btn" @click="closeForm">收起</button>
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
        <picker :range="formCategoryNames" @change="onFormCategoryChange">
          <view class="picker-display">{{ formCategoryName || '请选择分类' }}</view>
        </picker>
      </view>
      <view class="field">
        <text class="field-label">备注</text>
        <input v-model="form.remark" class="input" placeholder="请输入备注" />
      </view>
      <view class="button-row">
        <button class="btn btn-primary" @click="submitBill">保存</button>
        <button class="btn btn-secondary" @click="closeForm">取消</button>
      </view>
    </view>

    <view class="section list">
      <view v-if="!billStore.bills.length" class="empty panel">暂无账单</view>
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
const categoryFilterNames = computed(() => ['全部分类', ...billStore.categories.map((item) => item.name)])
const currentCategoryName = computed(() => {
  if (!filters.category_id) return '全部分类'
  return billStore.categories.find((item) => item.id === filters.category_id)?.name || '全部分类'
})
const formCategories = computed(() => billStore.categories.filter((item) => item.type === form.bill_type))
const formCategoryNames = computed(() => formCategories.value.map((item) => item.name))
const formCategoryName = computed(() => formCategories.value.find((item) => item.id === form.category_id)?.name || '')

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
  filters.category_id = index === 0 ? '' : billStore.categories[index - 1]?.id || ''
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
.block {
  display: block;
  margin-top: 8rpx;
}

.section-title {
  font-size: 30rpx;
  font-weight: 900;
}

.small-btn,
.text-btn,
.filter-chip {
  margin: 0;
  height: 58rpx;
  line-height: 58rpx;
  padding: 0 18rpx;
  border: 1rpx solid #dce4dd;
  border-radius: 8px;
  background: #fff;
  color: #15211a;
  font-size: 24rpx;
}

.text-btn {
  border: 0;
  color: #1f6f78;
}

.filter-row {
  display: flex;
  gap: 12rpx;
  margin-top: 16rpx;
  overflow-x: auto;
}

.filter-chip {
  white-space: nowrap;
}

.no-top {
  margin-top: 0;
}

.bill-gap {
  margin-bottom: 16rpx;
}
</style>
