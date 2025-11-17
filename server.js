// server.js (최종 로컬 테스트 버전)

const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
require('dotenv').config(); // .env 파일 로드
const path = require('path');
const fs = require('fs');

const User = require('./models/user');
const extinguisherRoutes = require('./routes/extinguishers'); // 소화기 라우터

const app = express();
// ✅ 로컬 테스트 포트 8080 고정
const PORT = 8080; 

// 환경 변수(.env 파일)에서 값 읽어오기
const JWT_SECRET = process.env.JWT_SECRET;
const MONGO_URI = process.env.MONGO_URI;

if (!JWT_SECRET || !MONGO_URI) {
  console.error('오류: .env 파일에 JWT_SECRET 또는 MONGO_URI가 설정되지 않았습니다.');
  process.exit(1);
}

// DB 연결
async function connectDB() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('MongoDB Atlas에 성공적으로 연결되었습니다.');
  } catch (err) {
    console.error('MongoDB 연결 오류:', err.message);
    process.exit(1);
  }
}
connectDB(); // 서버 시작 시 DB 연결

// 업로드 폴더 설정 및 생성
const uploadDir = 'uploads/';
if (!fs.existsSync(uploadDir)){
    fs.mkdirSync(uploadDir);
    console.log(`'${uploadDir}' 폴더를 생성했습니다.`);
}

// 정적 파일 제공 설정 (업로드된 이미지 접근)
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// --- 🚨 순서 중요: Multer를 사용하는 라우터를 JSON 파서보다 먼저 연결 ---
app.use('/api/v1/extinguishers', extinguisherRoutes); 

// --- JSON 파서 (Multipart 요청 처리 후 실행) ---
app.use(express.json()); // application/json 파싱
app.use(express.urlencoded({ extended: true }));

// --- 사용자 인증 API (JSON 파서가 필요) ---
// 회원가입 API: POST /api/v1/register
app.post('/api/v1/register', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ message: '아이디와 비밀번호를 모두 입력해주세요.' });
  }
  try {
    let user = await User.findOne({ username });
    if (user) {
      return res.status(400).json({ message: '이미 존재하는 아이디입니다.' });
    }
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);
    user = new User({ username, password: hashedPassword });
    await user.save();
    console.log('회원가입 성공:', username);
    return res.status(201).json({ message: '회원가입이 성공적으로 완료되었습니다.' });
  } catch (err) {
    console.error('회원가입 오류:', err.message);
    return res.status(500).json({ message: '서버 오류가 발생했습니다.' });
  }
});

// 로그인 API: POST /api/v1/login (JWT 발급)
app.post('/api/v1/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ message: '아이디와 비밀번호를 모두 입력해주세요.' });
  }
  try {
    const user = await User.findOne({ username });
    if (!user) {
      return res.status(401).json({ message: '아이디 또는 비밀번호가 올바르지 않습니다.' });
    }
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: '아이디 또는 비밀번호가 올바르지 않습니다.' });
    }

    const payload = { userId: user.id, username: user.username };
    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: '1h' }); 
    
    console.log('로그인 성공 (JWT 발급):', username);
    return res.status(200).json({
      message: '로그인 성공',
      accessToken: token,
      userId: user.username,
    });
  } catch (err) {
    console.error('로그인 오류:', err.message);
    return res.status(500).json({ message: '서버 오류가 발생했습니다.' });
  }
});

// 서버 시작 (PC의 모든 IP 주소에 바인딩)
app.listen(PORT, '0.0.0.0', () => { 
    console.log(`서버가 포트 ${PORT}에서 실행 중입니다.`);
    console.log(`접속 주소(에뮬레이터용): http://10.0.2.2:8080/api/v1`); 
});