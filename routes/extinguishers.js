// routes/extinguishers.js

const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const Extinguisher = require('../models/Extinguisher');
const multer = require('multer');
const fs = require('fs');
const path = require('path');

// --- Multer (파일 업로드) 설정 ---
const uploadDir = 'uploads/';
if (!fs.existsSync(uploadDir)){ fs.mkdirSync(uploadDir); }

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir); 
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname));
  }
});
const upload = multer({ storage: storage });
// --- Multer 설정 끝 ---


// --- 모든 소화기 API는 인증 미들웨어를 통과해야 함 ---
router.use(authMiddleware);

// --- 1. 소화기 등록: POST /api/v1/extinguishers ---
router.post('/', upload.single('image'), async (req, res) => {
  console.log(`[POST /extinguishers] 핸들러 시작 by ${req.user.username}`);
  const { name, isSoundOn, isLightOn } = req.body;
  console.log(`[POST /extinguishers] 요청 Body:`, req.body);
  console.log(`[POST /extinguishers] 파일 수신:`, req.file); 

  if (!name) {
    console.log('[POST /extinguishers] 오류: 이름 누락');
    return res.status(400).json({ message: '소화기 이름을 입력해주세요.' });
  }

  let imagePath = null;
  if (req.file) {
    imagePath = `/${req.file.destination}${req.file.filename}`;
  }

  try {
    console.log(`[POST /extinguishers] DB 저장 시도: ${name}`);
    const newExtinguisher = new Extinguisher({
      name,
      imagePath: imagePath,
      isSoundOn: isSoundOn === 'true' || isSoundOn === true,
      isLightOn: isLightOn === 'true' || isLightOn === true,
      owner: req.user.id,
    });
    
    await newExtinguisher.save();
    console.log(`[POST /extinguishers] newExtinguisher.save() 호출 완료`);
    console.log(`[소화기 등록] 성공: ${newExtinguisher.name} by ${req.user.username}`);
    res.status(201).json(newExtinguisher);

  } catch (err) {
    console.error('[POST /extinguishers] Catch 블록 오류:', err.message, err.stack);
    res.status(500).json({ message: '서버 오류 발생' });
  }
});

// --- 2. 목록 조회: GET /api/v1/extinguishers ---
router.get('/', async (req, res) => {
  console.log(`[GET /extinguishers] 핸들러 시작 by ${req.user.username}`);
  try {
    console.log(`[GET /extinguishers] DB 조회 시작 (owner: ${req.user.id})`);
    const extinguishers = await Extinguisher.find({ owner: req.user.id })
                                            .sort({ createdAt: -1 });
    console.log(`[GET /extinguishers] DB 조회 완료 (${extinguishers.length}개)`);
    res.status(200).json(extinguishers);
  } catch (err) {
    console.error('[GET /extinguishers] Catch 블록 오류:', err.message, err.stack);
    res.status(500).json({ message: '서버 오류 발생' });
  }
});

// --- 3. 삭제: DELETE /api/v1/extinguishers/:id ---
router.delete('/:id', async (req, res) => {
  console.log(`[DELETE /extinguishers/:id] 핸들러 시작 by ${req.user.username}`);
  try {
    const extinguisherId = req.params.id;
    const extinguisher = await Extinguisher.findById(extinguisherId);

    if (!extinguisher) {
      return res.status(404).json({ message: '삭제할 소화기를 찾을 수 없습니다.' });
    }
    if (extinguisher.owner.toString() !== req.user.id) {
      return res.status(403).json({ message: '삭제 권한이 없습니다.' });
    }

    await Extinguisher.findByIdAndDelete(extinguisherId);
    console.log(`[DELETE /extinguishers/:id] 성공: ID ${extinguisherId}`);
    res.status(200).json({ message: '소화기가 성공적으로 삭제되었습니다.' });

  } catch (err) {
    console.error('[DELETE /extinguishers/:id] Catch 블록 오류:', err.message, err.stack);
    res.status(500).json({ message: '서버 오류가 발생했습니다.' });
  }
});

// --- 4. 수정 (텍스트/스위치): PUT /api/v1/extinguishers/:id ---
router.put('/:id', async (req, res) => {
  console.log(`[PUT /extinguishers/:id] 핸들러 시작 by ${req.user.username}`);
  try {
    const extinguisherId = req.params.id;
    const updates = req.body;
    if (updates.imagePath) { delete updates.imagePath; } // 이미지 경로는 별도 API로

    const extinguisher = await Extinguisher.findById(extinguisherId);

    if (!extinguisher) {
      return res.status(404).json({ message: '수정할 소화기를 찾을 수 없습니다.' });
    }
    if (extinguisher.owner.toString() !== req.user.id) {
      return res.status(403).json({ message: '수정 권한이 없습니다.' });
    }

    const updatedExtinguisher = await Extinguisher.findByIdAndUpdate(
      extinguisherId,
      { $set: updates },
      { new: true, runValidators: true }
    );
    
    console.log(`[PUT /extinguishers/:id] 성공: ID ${extinguisherId}`);
    res.status(200).json(updatedExtinguisher);

  } catch (err) {
    console.error('[PUT /extinguishers/:id] Catch 블록 오류:', err.message, err.stack);
    res.status(500).json({ message: '서버 오류 발생' });
  }
});

// --- 5. 이미지 업로드/수정: PUT /api/v1/extinguishers/upload/:id ---
router.put('/upload/:id', upload.single('image'), async (req, res) => {
    console.log(`[PUT /upload/:id] 핸들러 시작 by ${req.user.username}`);
    const extinguisherId = req.params.id;
    
    if (!req.file) {
        return res.status(400).json({ message: '업로드된 이미지가 없습니다.' });
    }

    const extinguisher = await Extinguisher.findById(extinguisherId);

    if (!extinguisher || extinguisher.owner.toString() !== req.user.id) {
        if (req.file) fs.unlinkSync(req.file.path);
        return res.status(403).json({ message: '권한이 없습니다.' });
    }

    // 이전 파일 삭제
    if (extinguisher.imagePath) {
        try {
            const oldFilePath = path.join(__dirname, '..', extinguisher.imagePath);
            fs.unlinkSync(oldFilePath);
        } catch (e) {
            console.error(`[이미지 업로드] 이전 파일 삭제 실패: ${e.message}`);
        }
    }

    // 새 이미지 경로
    const newImagePath = `/${req.file.destination}${req.file.filename}`;

    try {
        const updatedExtinguisher = await Extinguisher.findByIdAndUpdate(
            extinguisherId,
            { imagePath: newImagePath }, // imagePath만 업데이트
            { new: true }
        );

        console.log(`[이미지 업로드] 성공: ID ${extinguisherId}`);
        return res.status(200).json({ 
            message: '이미지 업로드 성공', 
            imagePath: updatedExtinguisher.imagePath
        });

    } catch (err) {
        if (req.file) fs.unlinkSync(req.file.path);
        console.error('[이미지 업로드] DB 업데이트 오류:', err.message);
        res.status(500).json({ message: 'DB 업데이트 중 서버 오류 발생' });
    }
});

module.exports = router;