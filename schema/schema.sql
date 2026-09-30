-- 도서관 대여 관리 학습용 스키마
-- 대상 DBMS: MySQL 8.4
-- 주의: 이 파일은 아래 6개 학습 테이블을 삭제한 뒤 다시 만든다.

-- MySQL 전용 문법: utf8mb4_0900_ai_ci는 MySQL 8 계열의 유니코드 콜레이션이다.
CREATE DATABASE IF NOT EXISTS library_learning
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE library_learning;

-- FK 자식 테이블부터 삭제해야 부모 테이블 삭제 시 FK 오류가 발생하지 않는다.
DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS book_authors;
DROP TABLE IF EXISTS books;
DROP TABLE IF EXISTS authors;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS members;

CREATE TABLE members (
    -- MySQL 전용 문법: AUTO_INCREMENT는 새 회원의 PK를 자동 생성한다.
    member_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    member_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NULL,
    joined_on DATE NOT NULL,
    membership_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT uq_members_email UNIQUE (email),
    CONSTRAINT chk_members_status
        CHECK (membership_status IN ('ACTIVE', 'SUSPENDED', 'WITHDRAWN'))
) ENGINE = InnoDB
  COMMENT = '도서관 회원 기본 정보';

CREATE TABLE categories (
    category_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NULL,
    CONSTRAINT uq_categories_name UNIQUE (category_name)
) ENGINE = InnoDB
  COMMENT = '도서 분류 정보';

CREATE TABLE authors (
    author_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    author_name VARCHAR(150) NOT NULL,
    country VARCHAR(100) NULL,
    birth_date DATE NULL
) ENGINE = InnoDB
  COMMENT = '저자 정보';

CREATE TABLE books (
    book_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category_id SMALLINT UNSIGNED NOT NULL,
    isbn CHAR(13) NOT NULL,
    title VARCHAR(255) NOT NULL,
    published_on DATE NULL,
    total_copies SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_books_isbn UNIQUE (isbn),
    CONSTRAINT chk_books_total_copies CHECK (total_copies > 0),
    CONSTRAINT fk_books_category
        FOREIGN KEY (category_id) REFERENCES categories (category_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) ENGINE = InnoDB
  COMMENT = '도서 기본 정보와 보유 권수';

CREATE TABLE book_authors (
    book_id BIGINT UNSIGNED NOT NULL,
    author_id BIGINT UNSIGNED NOT NULL,
    author_order TINYINT UNSIGNED NOT NULL DEFAULT 1,
    -- 복합 PK는 같은 도서와 저자의 연결이 중복 저장되는 것을 막는다.
    CONSTRAINT pk_book_authors PRIMARY KEY (book_id, author_id),
    CONSTRAINT uq_book_authors_order UNIQUE (book_id, author_order),
    CONSTRAINT chk_book_authors_order CHECK (author_order > 0),
    CONSTRAINT fk_book_authors_book
        FOREIGN KEY (book_id) REFERENCES books (book_id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE,
    CONSTRAINT fk_book_authors_author
        FOREIGN KEY (author_id) REFERENCES authors (author_id)
        ON UPDATE RESTRICT
        ON DELETE CASCADE
) ENGINE = InnoDB
  COMMENT = '도서와 저자의 N:M 관계를 해소하는 연결 테이블';

CREATE TABLE loans (
    loan_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    member_id BIGINT UNSIGNED NOT NULL,
    book_id BIGINT UNSIGNED NOT NULL,
    loaned_on DATE NOT NULL,
    due_on DATE NOT NULL,
    returned_on DATE NULL,
    CONSTRAINT chk_loans_due_date CHECK (due_on >= loaned_on),
    CONSTRAINT chk_loans_return_date
        CHECK (returned_on IS NULL OR returned_on >= loaned_on),
    CONSTRAINT fk_loans_member
        FOREIGN KEY (member_id) REFERENCES members (member_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,
    CONSTRAINT fk_loans_book
        FOREIGN KEY (book_id) REFERENCES books (book_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) ENGINE = InnoDB
  COMMENT = '회원별 도서 대여와 반납 이력';

-- total_copies보다 많은 동시 대여를 FK나 CHECK만으로 완전히 막을 수는 없다.
-- 이 과제에서는 Trigger/Procedure를 금지하므로 샘플 데이터와 대여 가능 수 조회로 정합성을 확인한다.

