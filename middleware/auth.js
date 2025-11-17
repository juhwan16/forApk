// middleware/auth.js (환경 변수 적용)

const jwt = require('jsonwebtoken');
const User = require('../models/user');
require('dotenv').config(); // ✅ .env 파일 로드를 위해 추가

// ✅ 환경 변수(.env 파일)에서 값 읽어오기
const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET) {
  console.error('오류: .env 파일에 JWT_SECRET가 설정되지 않았습니다.');
}

// 인증 미들웨어 함수
const authMiddleware = async (req, res, next) => {
  console.log(`[인증 미들웨어] 요청 수신: ${req.method} ${req.originalUrl}`);
  const authHeader = req.header('Authorization');
  console.log(`[인증 미들웨어] Authorization 헤더: ${authHeader}`);
  const token = authHeader && authHeader.startsWith('Bearer ') ? authHeader.substring(7) : null;

  if (!token) {
    console.log('[인증 미들웨어] 실패: 토큰 없음');
    return res.status(401).json({ message: '인증 토큰이 없습니다. 로그인해주세요.' });
  }

  try {
    console.log('[인증 미들웨어] 토큰 검증 시작');
    const decoded = jwt.verify(token, JWT_SECRET); 
    console.log('[인증 미들웨어] 토큰 검증 성공. Decoded:', decoded);

    console.log(`[인증 미들웨어] DB에서 사용자 조회 시작: User ID = ${decoded.userId}`);
    const user = await User.findById(decoded.userId);
    if (!user) {
        console.log('[인증 미들웨어] 실패: DB에서 사용자를 찾을 수 없음');
        throw new Error('사용자를 찾을 수 없습니다.');
    }
    console.log(`[인증 미들웨어] DB 사용자 조회 성공: ${user.username}`);

    req.user = user; // 요청 객체에 사용자 정보 추가

    console.log('[인증 미들웨어] 통과 (next 호출)');
    next();

  } catch (err) {
    console.error('[인증 미들웨어] JWT 검증/처리 오류:', err.message);
    let message = '인증 처리 중 오류가 발생했습니다.';
    if (err.name === 'JsonWebTokenError') {
      message = '유효하지 않은 토큰입니다.';
    }
    if (err.name === 'TokenExpiredError') {
      message = '토큰이 만료되었습니다. 다시 로그인해주세요.';
    }
    return res.status(401).json({ message });
  }
};

module.exports = authMiddleware;