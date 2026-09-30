-- 도서관 대여 관리 프로젝트 자동 검증
-- 실행 시점: schema.sql → seed.sql → queries.sql 실행 후

USE library_learning;

-- Verification 01
-- 목적: 과제에 필요한 기본 테이블이 정확히 6개인지 확인한다.
SELECT
    '테이블 6개' AS check_item,
    COUNT(*) AS actual_value,
    6 AS expected_value,
    IF(COUNT(*) = 6, 'PASS', 'FAIL') AS result
FROM information_schema.tables
WHERE table_schema = 'library_learning'
  AND table_type = 'BASE TABLE';

-- Verification 02
-- 목적: 6개 테이블 모두 PRIMARY KEY를 가지는지 확인한다.
SELECT
    '모든 테이블에 PK' AS check_item,
    COUNT(DISTINCT table_name) AS actual_value,
    6 AS expected_value,
    IF(COUNT(DISTINCT table_name) = 6, 'PASS', 'FAIL') AS result
FROM information_schema.table_constraints
WHERE constraint_schema = 'library_learning'
  AND constraint_type = 'PRIMARY KEY';

-- Verification 03
-- 목적: FK가 최소 2개라는 조건과 실제 설계의 FK 5개를 확인한다.
SELECT
    'FK 5개' AS check_item,
    COUNT(*) AS actual_value,
    5 AS expected_value,
    IF(COUNT(*) = 5, 'PASS', 'FAIL') AS result
FROM information_schema.table_constraints
WHERE constraint_schema = 'library_learning'
  AND constraint_type = 'FOREIGN KEY';

-- Verification 04
-- 목적: UNIQUE와 NOT NULL 제약조건이 실제 메타데이터에 존재하는지 확인한다.
SELECT
    'UNIQUE 제약 존재' AS check_item,
    COUNT(*) AS actual_value,
    1 AS expected_minimum,
    IF(COUNT(*) >= 1, 'PASS', 'FAIL') AS result
FROM information_schema.table_constraints
WHERE constraint_schema = 'library_learning'
  AND constraint_type = 'UNIQUE'
UNION ALL
SELECT
    'NOT NULL 컬럼 존재',
    COUNT(*),
    1,
    IF(COUNT(*) >= 1, 'PASS', 'FAIL')
FROM information_schema.columns
WHERE table_schema = 'library_learning'
  AND is_nullable = 'NO';

-- Verification 05
-- 목적: 각 테이블의 샘플 데이터가 10행 이상인지 확인한다.
SELECT table_name, row_count, 10 AS expected_minimum,
       IF(row_count >= 10, 'PASS', 'FAIL') AS result
FROM (
    SELECT 'members' AS table_name, COUNT(*) AS row_count FROM members
    UNION ALL
    SELECT 'categories', COUNT(*) FROM categories
    UNION ALL
    SELECT 'authors', COUNT(*) FROM authors
    UNION ALL
    SELECT 'books', COUNT(*) FROM books
    UNION ALL
    SELECT 'book_authors', COUNT(*) FROM book_authors
    UNION ALL
    SELECT 'loans', COUNT(*) FROM loans
) AS row_counts
ORDER BY table_name;

-- Verification 06
-- 목적: Query 18의 복합 인덱스가 정확한 컬럼 순서로 만들어졌는지 확인한다.
SELECT
    '복합 인덱스 컬럼 2개' AS check_item,
    COUNT(*) AS actual_value,
    2 AS expected_value,
    IF(
        COUNT(*) = 2
        AND GROUP_CONCAT(column_name ORDER BY seq_in_index) = 'book_id,returned_on',
        'PASS',
        'FAIL'
    ) AS result
FROM information_schema.statistics
WHERE table_schema = 'library_learning'
  AND table_name = 'loans'
  AND index_name = 'idx_loans_book_returned';

-- Verification 07
-- 목적: 샘플 데이터에서 보유 권수보다 많은 동시 대여가 없는지 확인한다.
SELECT
    '대여 가능 권수 음수 없음' AS check_item,
    MIN(b.total_copies - COALESCE(active_loans.active_count, 0)) AS minimum_available_copies,
    0 AS expected_minimum,
    IF(
        MIN(b.total_copies - COALESCE(active_loans.active_count, 0)) >= 0,
        'PASS',
        'FAIL'
    ) AS result
FROM books AS b
LEFT JOIN (
    SELECT book_id, COUNT(*) AS active_count
    FROM loans
    WHERE returned_on IS NULL
    GROUP BY book_id
) AS active_loans ON active_loans.book_id = b.book_id;

-- Verification 08
-- 목적: UPDATE/DELETE 실습의 ROLLBACK으로 원본 행이 유지되었는지 확인한다.
SELECT
    'UPDATE 롤백 확인' AS check_item,
    IF(returned_on IS NULL, 1, 0) AS actual_value,
    1 AS expected_value,
    IF(returned_on IS NULL, 'PASS', 'FAIL') AS result
FROM loans
WHERE loan_id = 22
UNION ALL
SELECT
    'DELETE 롤백 확인',
    COUNT(*),
    1,
    IF(COUNT(*) = 1, 'PASS', 'FAIL')
FROM members
WHERE member_id = 12;

-- 보너스: 아래 문장의 주석을 해제해 따로 실행하면 FK 오류가 발생해야 한다.
-- 존재하지 않는 member_id 9999를 참조하므로 MySQL 오류 1452가 정상 결과다.
-- INSERT INTO loans
--     (member_id, book_id, loaned_on, due_on, returned_on)
-- VALUES
--     (9999, 1, '2026-09-20', '2026-10-04', NULL);

