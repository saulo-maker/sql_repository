CREATE OR REPLACE PROCEDURE "STP_ATUALIZACUSTOPAPI" (
       P_CODUSU NUMBER,        -- Código do usuário logado
       P_IDSESSAO VARCHAR2,    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execução.
       P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
       FIELD_CODPRODPA NUMBER;
       FIELD_IDPROC NUMBER;
       V_VLMP NUMBER;
       EXTPROD NUMBER;
       EXCPROD NUMBER;
       TPPROD VARCHAR(2);
       V_VLRVENDA FLOAT(126);
BEGIN

       -- Os valores informados pelo formulário de parâmetros, podem ser obtidos com as funções:
       --     ACT_INT_PARAM
       --     ACT_DEC_PARAM
       --     ACT_TXT_PARAM
       --     ACT_DTA_PARAM
       -- Estas funções recebem 2 argumentos:
       --     ID DA SESSÃO - Identificador da execução (Obtido através de P_IDSESSAO))
       --     NOME DO PARAMETRO - Determina qual parametro deve se deseja obter.


       FOR I IN 1..P_QTDLINHAS -- Este loop permite obter o valor de campos dos registros envolvidos na execução.
       LOOP                    -- A variável "I" representa o registro corrente.
           -- Para obter o valor dos campos utilize uma das seguintes funções:
           --     ACT_INT_FIELD (Retorna o valor de um campo tipo NUMÉRICO INTEIRO))
           --     ACT_DEC_FIELD (Retorna o valor de um campo tipo NUMÉRICO DECIMAL))
           --     ACT_TXT_FIELD (Retorna o valor de um campo tipo TEXTO),
           --     ACT_DTA_FIELD (Retorna o valor de um campo tipo DATA)
           -- Estas funções recebem 3 argumentos:
           --     ID DA SESSÃO - Identificador da execução (Obtido através do parâmetro P_IDSESSAO))
           --     NÚMERO DA LINHA - Relativo a qual linha selecionada.
           --     NOME DO CAMPO - Determina qual campo deve ser obtido.
           FIELD_CODPRODPA := ACT_INT_FIELD(P_IDSESSAO, I, 'CODPRODPA');
           FIELD_IDPROC := ACT_INT_FIELD(P_IDSESSAO, I, 'IDPROC');

        -- <Obtenho os preços do produto>
        SELECT
        SUM(OBTEMCUSTO_HDN(M.CODPRODMP,'S',1 , 'N', 0, 'N' ,' ' ,SYSDATE,2) * QTDMISTURA) AS VLPA
        INTO V_VLMP
        FROM TPRLMP M
        LEFT JOIN TPRATV A ON A.IDEFX = M.IDEFX
        WHERE M.CODPRODPA = FIELD_CODPRODPA
        AND A.IDPROC = FIELD_IDPROC;
        
       SELECT SUM(NVL(QTD,0)*NVL(VLRUNIT,0)) + V_VLMP
       INTO V_VLMP
       FROM AD_SERCOMP
       WHERE CODPRODPA = FIELD_CODPRODPA
       AND CODEMP = ( SELECT PR.CODPLP
                      FROM TPRPRC PR 
                      WHERE PR.IDPROC = FIELD_IDPROC
                      AND PR.VERSAO = (SELECT MAX(P.VERSAO) FROM TPRPRC P WHERE P.CODPRC = PR.CODPRC));
        
        BEGIN
            SELECT COUNT(C.CODPROD)
            INTO EXTPROD
            FROM TGFCUS C
            WHERE C.CODPROD = FIELD_CODPRODPA
            AND C.DTATUAL = (SELECT MAX(DTATUAL) FROM TGFCUS WHERE CODPROD = C.CODPROD)
            GROUP BY C.CODPROD;
        EXCEPTION 
            WHEN NO_DATA_FOUND THEN
                EXTPROD := 0;
        END;
       
        BEGIN
            SELECT EX.CODPROD
            INTO EXCPROD
            FROM TGFEXC EX
            WHERE EX.CODPROD = FIELD_CODPRODPA;
        EXCEPTION 
            WHEN NO_DATA_FOUND THEN
                EXCPROD := 0;
        END;
        
        BEGIN
            SELECT P.USOPROD
            INTO TPPROD
            FROM TGFPRO P
            WHERE P.CODPROD = FIELD_CODPRODPA;
        EXCEPTION 
            WHEN NO_DATA_FOUND THEN
               TPPROD := NULL;
        END;
        
        BEGIN
            SELECT get_preco_hd(1, FIELD_CODPRODPA) 
            INTO V_VLRVENDA
            FROM TPRLPA TA
            WHERE TA.CODPRODPA = FIELD_CODPRODPA
            AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
            V_VLRVENDA := 0;
        END;
        
        IF EXTPROD = 0
            THEN
              INSERT INTO tgfcus (codprod,codemp,dtatual,cusmedicm,cussemicm,cusrep,cusvariavel,cusger,cusmed)
              VALUES (FIELD_CODPRODPA,1,SYSDATE,V_VLMP,V_VLMP,V_VLMP,V_VLMP,V_VLMP,V_VLMP);
              INSERT INTO tgfcus (codprod,codemp,dtatual,cusmedicm,cussemicm,cusrep,cusvariavel,cusger,cusmed)
              VALUES (FIELD_CODPRODPA,2,SYSDATE,V_VLMP,V_VLMP,V_VLMP,V_VLMP,V_VLMP,V_VLMP);
        ELSE
            UPDATE TGFCUS T
            SET 
                t.cusmedicm = V_VLMP,
                t.cussemicm = V_VLMP,
                t.cusrep = V_VLMP,
                t.cusvariavel = V_VLMP,
                t.cusger = V_VLMP,
                t.cusmed = V_VLMP
            WHERE T.CODPROD = FIELD_CODPRODPA
              AND T.CODEMP IN (1, 2)
              AND T.DTATUAL = (SELECT MAX(DTATUAL) FROM TGFCUS WHERE CODPROD = FIELD_CODPRODPA);
        END IF;
        
        IF EXCPROD = 0
            THEN 
                 INSERT INTO TGFEXC (NUTAB, CODPROD, CODLOCAL, CONTROLE, VLRVENDA, TIPO) 
                 VALUES (13, FIELD_CODPRODPA, '100000000', ' ', V_VLRVENDA, TPPROD);
        ELSE
                 UPDATE TGFEXC EX
                 SET EX.VLRVENDA = V_VLRVENDA
                 WHERE EX.CODPROD = FIELD_CODPRODPA;
        END IF;
       END LOOP;

    P_MENSAGEM := 'Atualizado com sucesso';


END;
