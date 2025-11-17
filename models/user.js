// models/user.js

const mongoose = require('mongoose');

// 사용자 데이터 구조 정의
const userSchema = new mongoose.Schema({
    username: { // Flutter 앱의 'username' 또는 'email' 필드와 일치
        type: String,
        required: true,
        unique: true, // 아이디(이메일)는 고유해야 함
        lowercase: true,
    },
    password: { // 실제로는 암호화된 비밀번호를 저장
        type: String,
        required: true,
    },
    createdAt: { // 가입일
        type: Date,
        default: Date.now,
    },
});

// 'User'라는 이름으로 모델 생성 및 내보내기
module.exports = mongoose.model('User', userSchema);