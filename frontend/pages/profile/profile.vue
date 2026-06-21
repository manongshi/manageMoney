<template>
  <view class="page">
    <view class="section title-row">
      <view>
        <text class="page-title">我的</text>
        <text class="muted block">账号与设置</text>
      </view>
    </view>

    <view class="section panel profile-card">
      <view class="avatar">{{ initial }}</view>
      <view class="profile-info">
        <text class="nickname">{{ user?.nickname || '未登录' }}</text>
        <text class="muted">{{ user?.username || '请先登录' }}</text>
      </view>
    </view>

    <view class="section panel">
      <view class="row">
        <text>用户ID</text>
        <text class="muted">{{ user?.id || '-' }}</text>
      </view>
      <view class="row">
        <text>性别</text>
        <text class="muted">{{ genderText }}</text>
      </view>
      <view class="row">
        <text>创建时间</text>
        <text class="muted">{{ user?.create_time || '-' }}</text>
      </view>
    </view>

    <view class="section panel">
      <button v-if="userStore.token" class="btn btn-danger" @click="doLogout">退出登录</button>
      <button v-else class="btn btn-primary" @click="goLogin">去登录</button>
    </view>
  </view>
</template>

<script setup>
import { computed } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useUserStore } from '../../store/user'

const userStore = useUserStore()
const user = computed(() => userStore.user)
const initial = computed(() => (user.value?.nickname || user.value?.username || '账').slice(0, 1))
const genderText = computed(() => {
  if (user.value?.gender === 1) return '男'
  if (user.value?.gender === 2) return '女'
  return '未设置'
})

async function load() {
  if (!userStore.token) return
  try {
    await userStore.loadProfile()
  } catch (error) {
    uni.showToast({ title: error.message, icon: 'none' })
  }
}

async function doLogout() {
  await userStore.logout()
  uni.redirectTo({ url: '/pages/login/login' })
}

function goLogin() {
  uni.redirectTo({ url: '/pages/login/login' })
}

onShow(load)
</script>

<style scoped>
.block {
  display: block;
  margin-top: 8rpx;
}

.profile-card {
  display: flex;
  align-items: center;
  gap: 22rpx;
}

.avatar {
  width: 108rpx;
  height: 108rpx;
  border-radius: 8px;
  background: #15211a;
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 46rpx;
  font-weight: 900;
}

.profile-info {
  display: flex;
  flex-direction: column;
  gap: 8rpx;
}

.nickname {
  font-size: 36rpx;
  font-weight: 900;
}

.row {
  min-height: 76rpx;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1rpx solid #eef3ef;
  font-size: 28rpx;
}

.row:last-child {
  border-bottom: 0;
}
</style>
