const express = require("express");
const router = express.Router();
const authController = require("../controllers/authController");
const authMiddleware = require("../middleware/auth");

router.post("/register", authController.register);
router.post("/login", authController.login);
router.post("/logout", authController.logout);
router.get("/session", authController.checkSession);
router.get("/me", authMiddleware, authController.getMe);
router.put("/update-profile", authMiddleware, authController.updateProfile);

module.exports = router;