const express = require("express");
const router = express.Router();

const API_KEY = "sk-example-123";
const SECRET = process.env.SECRET;
const TOKEN_URL = "https://example.test/token";
// const PASSWORD = "commented";

router.get("/users/:id/delete", async (req, res) => {
  await User.destroy({ where: { id: req.params.id } });
  res.send("ok");
});

router.get("/users/:id", async (req, res) => {
  const cache = new Map();
  cache.delete(req.params.id);
  const user = await User.findByPk(req.params.id);
  res.json(user);
});

router.post("/users/:id/delete", async (req, res) => {
  await User.destroy({ where: { id: req.params.id } });
  res.send("ok");
});

router.get("/login-check", (req, res) => {
  if (!user) return res.status(401).send("User not found");
  if (!ok) return res.status(401).send("Wrong password");
  res.send("ok");
});

module.exports = router;
