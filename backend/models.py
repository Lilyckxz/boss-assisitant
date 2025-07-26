# !/user/bin/env python3
# -*- coding: utf-8 -*-

from sqlalchemy import Column, Integer, String, Boolean, DateTime
from datetime import datetime
from database import Base

class Todo(Base):
    __tablename__ = "todos"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True)
    completed = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    remind_at = Column(DateTime, nullable=True)
    user_id = Column(Integer, index=True)  # 新增：每条待办关联用户

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class StashContent(Base):
    __tablename__ = "stash_content"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    url = Column(String, nullable=True)
    type = Column(String, default="article")  # 支持: article, video
    summary = Column(String, nullable=True)
    cover = Column(String, nullable=True)
    content = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class UserProfile(Base):
    __tablename__ = "user_profiles"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True, nullable=False)  # 人物名
    traits = Column(String, nullable=True)  # 属性/描述（如"喜欢喝酒"）
    user_id = Column(Integer, index=True, nullable=False)  # 新增：关联用户ID
    created_at = Column(DateTime, default=datetime.utcnow)

class UserCategorySubscription(Base):
    __tablename__ = "user_category_subscription"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    category = Column(String, index=True)  # 如 'health', 'industry_report', 'finance_analysis'
    created_at = Column(DateTime, default=datetime.utcnow)
