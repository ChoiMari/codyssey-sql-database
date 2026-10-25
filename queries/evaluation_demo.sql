-- 도서관 대여 관리 데이터베이스 평가 시연용 SQL
-- 대상 DBMS: MySQL 8.4
-- 사전 조건: schema/schema.sql → data/seed.sql → queries/queries.sql 순서로 실행
-- 각 Demo 블록을 DBeaver에서 하나씩 선택해 실행하고 설명한다.

USE library_learning;

-- Demo 01
-- 목적: 과제 DB에 기본 테이블이 6개 존재함을 확인한다.
-- 설명: information_schema는 MySQL이 관리하는 DB 구조 메타데이터다.
SELECT table_name, table_comment
FROM information_schema.tables
WHERE table_schema = 'library_learning'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Demo 02
-- 목적: 모든 테이블에 정의된 PK 컬럼을 확인한다.
-- 설명: book_authors만 두 컬럼으로 이루어진 복합 PK이고 나머지는 단일 PK다.
SELECT
    tc.table_name,
    GROUP_CONCAT(kcu.column_name ORDER BY kcu.ordinal_position) AS primary_key_columns
FROM information_schema.table_constraints AS tc
INNER JOIN information_schema.key_column_usage AS kcu
    ON kcu.constraint_schema = tc.constraint_schema
   AND kcu.table_name = tc.table_name
   AND kcu.constraint_name = tc.constraint_name
WHERE tc.constraint_schema = 'library_learning'
  AND tc.constraint_type = 'PRIMARY KEY'
GROUP BY tc.table_name
ORDER BY tc.table_name;

-- Demo 03-A
-- 목적: FK 5개의 자식 컬럼과 참조 대상 컬럼을 확인한다.
-- 설명: FK는 존재하지 않는 부모 값을 참조하지 못하게 해 참조 무결성을 지킨다.
SELECT
    table_name AS child_table,
    column_name AS foreign_key_column,
    referenced_table_name AS parent_table,
    referenced_column_name AS referenced_primary_key
FROM information_schema.key_column_usage
WHERE constraint_schema = 'library_learning'
  AND referenced_table_name IS NOT NULL
ORDER BY child_table, foreign_key_column;

-- Demo 03-B (선택 시연: 아래 INSERT만 주석을 해제해 별도로 실행)
-- 목적: 존재하지 않는 회원을 참조하는 대여 입력이 실제로 차단되는지 확인한다.
-- 예상 결과: MySQL 오류 1452(Cannot add or update a child row)가 발생한다.
-- INSERT INTO loans
--     (member_id, book_id, loaned_on, due_on, returned_on)
-- VALUES
--     (9999, 1, '2026-10-25', '2026-11-08', NULL);

-- Demo 04
-- 목적: 모든 테이블에 샘플 데이터가 10행 이상인지 한 번에 확인한다.
-- 설명: 연결 테이블과 이력 테이블도 독립적인 샘플 행 수 조건을 충족한다.
SELECT table_name, row_count, IF(row_count >= 10, 'PASS', 'FAIL') AS result
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
) AS table_counts
ORDER BY table_name;

-- Demo 05
-- 목적: 회원 1명이 여러 대여 기록을 갖는 1:N 관계를 실제 결과로 보여 준다.
-- 설명: members가 1, loans가 N이며 N 쪽의 member_id가 FK다.
SELECT
    m.member_id,
    m.member_name,
    COUNT(l.loan_id) AS loan_count
FROM members AS m
LEFT JOIN loans AS l ON l.member_id = m.member_id
GROUP BY m.member_id, m.member_name
ORDER BY loan_count DESC, m.member_id;

-- Demo 06
-- 목적: 주요 컬럼의 타입과 NULL 허용 여부를 확인한다.
-- 설명: 숫자 식별자, 가변 문자열, 고정 길이 ISBN, 업무 날짜를 의미에 맞게 구분했다.
SELECT
    table_name,
    column_name,
    column_type,
    is_nullable,
    column_key,
    column_default
FROM information_schema.columns
WHERE table_schema = 'library_learning'
  AND table_name IN ('members', 'books', 'loans')
ORDER BY FIELD(table_name, 'members', 'books', 'loans'), ordinal_position;

-- Demo 07-A
-- 목적: INNER JOIN으로 실제 관계가 존재하는 대여 상세만 조회한다.
-- 설명: 기준 테이블은 사건 데이터인 loans이며 회원과 도서가 모두 일치하는 행만 남는다.
SELECT
    l.loan_id,
    m.member_name,
    b.title,
    l.loaned_on,
    l.returned_on
FROM loans AS l
INNER JOIN members AS m ON m.member_id = l.member_id
INNER JOIN books AS b ON b.book_id = l.book_id
ORDER BY l.loan_id;

-- Demo 07-B
-- 목적: LEFT JOIN으로 대여 이력이 없는 회원까지 찾는다.
-- 설명: members를 왼쪽 기준으로 유지하고, 연결되지 않은 loans의 PK가 NULL인 행을 찾는다.
SELECT
    m.member_id,
    m.member_name,
    l.loan_id
FROM members AS m
LEFT JOIN loans AS l ON l.member_id = m.member_id
WHERE l.loan_id IS NULL
ORDER BY m.member_id;

-- Demo 08
-- 목적: 카테고리 단위로 COUNT, SUM, AVG가 어떻게 동작하는지 함께 보여 준다.
-- 설명: COUNT는 도서 종류 수, SUM은 총 보유 권수, AVG는 도서당 평균 보유 권수다.
-- 도서가 없는 카테고리도 LEFT JOIN으로 유지하고 COALESCE로 NULL 집계를 0으로 표시한다.
SELECT
    c.category_id,
    c.category_name,
    COUNT(b.book_id) AS book_title_count,
    COALESCE(SUM(b.total_copies), 0) AS total_copy_count,
    ROUND(COALESCE(AVG(b.total_copies), 0), 1) AS avg_copies_per_title
FROM categories AS c
LEFT JOIN books AS b ON b.category_id = c.category_id
GROUP BY c.category_id, c.category_name
ORDER BY book_title_count DESC, c.category_id;

-- Demo 09
-- 목적: 복잡한 Query 12의 안쪽 단계인 회원별 대여 횟수를 먼저 확인한다.
-- 설명: 대여 0건 회원도 전체 평균 계산에 포함하기 위해 LEFT JOIN을 사용한다.
SELECT
    m.member_id,
    m.member_name,
    COUNT(l.loan_id) AS member_loan_count
FROM members AS m
LEFT JOIN loans AS l ON l.member_id = m.member_id
GROUP BY m.member_id, m.member_name
ORDER BY member_loan_count DESC, m.member_id;

-- Demo 10
-- 목적: 전체 회원 평균보다 많이 대여한 회원을 서브쿼리와 HAVING으로 찾는다.
-- 설명: 안쪽 파생 테이블이 회원별 횟수를 만들고 AVG가 평균을 계산한 뒤,
--       바깥 HAVING이 각 회원의 COUNT 결과와 평균을 비교한다.
SELECT
    m.member_id,
    m.member_name,
    COUNT(l.loan_id) AS loan_count
FROM members AS m
INNER JOIN loans AS l ON l.member_id = m.member_id
GROUP BY m.member_id, m.member_name
HAVING COUNT(l.loan_id) > (
    SELECT AVG(member_loan_count)
    FROM (
        SELECT m2.member_id, COUNT(l2.loan_id) AS member_loan_count
        FROM members AS m2
        LEFT JOIN loans AS l2 ON l2.member_id = m2.member_id
        GROUP BY m2.member_id
    ) AS member_counts
)
ORDER BY loan_count DESC, m.member_id;

-- Demo 11-A
-- 목적: Query 18에서 만든 복합 인덱스와 컬럼 순서를 확인한다.
-- 설명: book_id가 선두 컬럼이고 returned_on이 두 번째 컬럼이어야 한다.
SHOW INDEX FROM loans
WHERE Key_name = 'idx_loans_book_returned';

-- Demo 11-B
-- 목적: 특정 도서의 미반납 조회가 인덱스를 후보로 고려하는지 확인한다.
-- 설명: 데이터가 적으면 옵티마이저가 전체 스캔을 선택해 key가 NULL일 수도 있다.
EXPLAIN
SELECT loan_id, member_id, book_id, due_on
FROM loans
WHERE book_id = 3
  AND returned_on IS NULL;

-- Demo 12
-- 목적: UPDATE로 반납 처리한 결과를 보여 준 뒤 ROLLBACK으로 원상 복구한다.
-- 설명: PK와 현재 미반납 조건을 함께 사용해 한 행만 안전하게 수정한다.
START TRANSACTION;

UPDATE loans
SET returned_on = '2026-09-10'
WHERE loan_id = 22
  AND returned_on IS NULL;

SELECT loan_id, member_id, book_id, returned_on
FROM loans
WHERE loan_id = 22;

ROLLBACK;

-- Demo 13
-- 목적: 대여 이력이 없는 테스트 회원을 DELETE한 뒤 ROLLBACK으로 복구한다.
-- 설명: NOT EXISTS가 있어 대여 기록이 있는 회원은 삭제되지 않는다.
START TRANSACTION;

DELETE FROM members
WHERE member_id = 12
  AND NOT EXISTS (
      SELECT 1
      FROM loans
      WHERE loans.member_id = members.member_id
  );

SELECT member_id, member_name
FROM members
WHERE member_id = 12;

ROLLBACK;

