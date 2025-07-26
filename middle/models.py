from sqlalchemy import Column, Integer, String, UniqueConstraint
from .database import Base

class Category(Base):
    __tablename__ = "categories"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)

class UserPermission(Base):
    __tablename__ = "user_permissions"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True, nullable=False)
    category_name = Column(String, index=True, nullable=False)
    __table_args__ = (UniqueConstraint('user_id', 'category_name', name='_user_category_uc'),) 