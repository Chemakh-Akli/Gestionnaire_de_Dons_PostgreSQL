DROP TABLE IF EXISTS Streamer CASCADE;
DROP TABLE IF EXISTS Viewer CASCADE;
DROP TABLE IF EXISTS Cadeau CASCADE;
DROP TABLE IF EXISTS Cagnotte CASCADE;
DROP TABLE IF EXISTS Dons CASCADE;
DROP TABLE IF EXISTS Transaction CASCADE;
DROP TABLE IF EXISTS Giveaway;
DROP TABLE IF EXISTS Plateforme;
DROP TABLE IF EXISTS Abonnement;

  CREATE TABLE Streamer(
    id_streamer SERIAL Not NULL PRIMARY KEY,
    nom varchar(50),
    prenom varchar(50),
    pseudo varchar(50),
    mail varchar(100) UNIQUE,
    date_de_naissance DATE,
    solde INTEGER NOT NULL CHECK (solde >= 0)
  );

  CREATE TABLE Viewer(
    id_viewer serial Not NULL PRIMARY KEY,
    nom varchar(50),
    prenom varchar(50),
    pseudo varchar(50),
    mail varchar(100) UNIQUE,
    date_de_naissance DATE,
    solde INTEGER NOT NULL CHECK (solde >= 0)
  );

  CREATE TABLE Cadeau(
    id_cadeau SERIAL Not NULL  PRIMARY KEY,
    id_streamer INTEGER NOT NULL REFERENCES Streamer(id_streamer),
    description varchar(100),
    quantite INTEGER NOT NULL CHECK (quantite >= 0),
    seuil INTEGER NOT NULL CHECK (seuil >= 1 AND seuil <=3)
  );

  CREATE TABLE Giveaway(
    id_cadeau INTEGER NOT NULL REFERENCES Cadeau(id_cadeau),
    id_viewer INTEGER NOT NULL REFERENCES Viewer(id_viewer),
    date_giveaway TIMESTAMP NOT NULL,
    PRIMARY KEY (id_cadeau,id_viewer,date_giveaway)
  );

  CREATE TABLE Plateforme(
    societe varchar(50) NOT NULL PRIMARY KEY,
    solde INTEGER NOT NULL CHECK (solde >= 0 )
  );

  CREATE TABLE Abonnement(
    id_streamer INTEGER NOT NULL REFERENCES Streamer(id_streamer),
    id_viewer INTEGER NOT NULL REFERENCES Viewer(id_viewer),
    PRIMARY KEY (id_streamer,id_viewer)
  );

  CREATE TABLE Cagnotte(
    id_cagnotte SERIAL NOT NULL  PRIMARY KEY,
    id_streamer INTEGER NOT NULL REFERENCES Streamer(id_streamer),
    date_debut DATE NOT NULL,
    description varchar(400),
    solde INTEGER NOT NULL CHECK (solde >= 0),
    objectif_min INTEGER CHECK (objectif_min >=0 OR objectif_min = null),
    date_fin DATE,
    disponible boolean
  );

  CREATE TABLE Dons(
    id_don SERIAL NOT NULL PRIMARY KEY,
    id_cagnotte INTEGER NOT NULL REFERENCES Cagnotte(id_cagnotte),
    id_viewer INTEGER NOT NULL REFERENCES Viewer(id_viewer),
    montant_don INTEGER NOT NULL CHECK (montant_don > 0)
  );

  CREATE TABLE Transaction(
    id_don INTEGER NOT NULL REFERENCES Dons(id_don),
    type CHAR NOT NULL  CHECK (type in ('V','D','C')),
    montant_transaction INTEGER NOT NULL CHECK( montant_transaction >= 0 ),
    date_transaction TIMESTAMP NOT NULL,
    PRIMARY KEY(id_don,type)
  );





  /*Fonction */

  /*Lister les abonnés d'un streamer */

  CREATE OR REPLACE FUNCTION liste_abonnes_streamer(int)
  RETURNS SETOF Viewer AS
  $$
    SELECT v.* FROM  Viewer as v, Abonnement as a
    WHERE a.id_viewer = v.id_viewer AND a.id_streamer = $1;
  $$
  LANGUAGE SQL;

  /*Lister les cadeaux d'un viewer*/

  CREATE OR REPLACE FUNCTION liste_cadeaux_viewer(int)
  RETURNS SETOF Cadeau AS
  $$
    SELECT c.* FROM Cadeau as c, Giveaway as g
    WHERE g.id_viewer = $1 AND c.id_cadeau = g.id_cadeau;
  $$
  LANGUAGE SQL;

  /*Creer une Cagnotte personelle pour le streamer dès son inscription*/

  CREATE OR REPLACE FUNCTION cagnotte_perso()
  RETURNS TRIGGER AS
  $$
  BEGIN
    INSERT INTO Cagnotte(id_streamer,date_debut,description,solde,objectif_min,date_fin,disponible)
    VALUES (NEW.id_streamer,CURRENT_DATE,'Ma cagnotte',0,null,null,true);
    RETURN NEW;
  END;
  $$
  LANGUAGE plpgsql;

  /*Calcul de la commission en fonction du don*/

  CREATE OR REPLACE FUNCTION calcul_pourcentage_commission(int)
  RETURNS INTEGER AS
  $$
      DECLARE
          result int := 0;
      BEGIN
          IF ($1 < 100) THEN
           result:=10;
         ELSE
            IF ($1 >= 100) THEN
            result:=12;
         END IF;

      END IF;
      RETURN result;
    END;
  $$
  LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION get_solde_viewer(int)
  RETURNS INTEGER AS
  $$
    SELECT solde FROM Viewer,Dons WHERE Dons.id_viewer = $1;
  $$
  LANGUAGE SQL;

  CREATE OR REPLACE FUNCTION get_objectif_cagnotte(int)
  RETURNS INTEGER AS
  $$
          SELECT objectif_min FROM Cagnotte WHERE id_cagnotte = $1;
  $$
  LANGUAGE SQL;

  CREATE OR REPLACE FUNCTION type_cagnotte(int)
  RETURNS BOOLEAN AS
  $$
      DECLARE
          objectif integer := get_objectif_cagnotte($1);
          result boolean := false;
      BEGIN
          IF (objectif IS NULL) THEN
           RETURN TRUE;             /*TRUE == Sans objectif --- FALSE == Avec Objectif*/
         ELSE
            RETURN FALSE;
         END IF;
      RETURN result;
    END;
  $$
  LANGUAGE plpgsql;

  CREATE OR REPLACE FUNCTION get_id_cagnotte(int)
  RETURNS INTEGER AS
  $$
    SELECT id_cagnotte FROM Dons WHERE id_don = $1;
  $$
  LANGUAGE SQL;

  CREATE OR REPLACE FUNCTION get_solde_cagnotte(int)
  RETURNS INTEGER AS
  $$
          SELECT solde FROM Cagnotte WHERE id_cagnotte = $1;
  $$
  LANGUAGE SQL;

  CREATE OR REPLACE FUNCTION get_idStreamer_from_don(int)
  RETURNS INTEGER AS
  $$
    SELECT c.id_streamer FROM Cagnotte as c, Dons as d
    WHERE c.id_cagnotte = d.id_cagnotte AND d.id_don = $1;
  $$
  LANGUAGE SQL;

  CREATE OR REPLACE FUNCTION get_idStreamer_from_cagnotte(int)
  RETURNS INTEGER AS
  $$
    SELECT id_streamer FROM Cagnotte WHERE id_cagnotte = $1;
  $$
  LANGUAGE SQL;

  CREATE OR REPLACE FUNCTION get_cagnotte_dispo(int)
  RETURNS BOOLEAN AS
  $$
  SELECT disponible FROM Cagnotte WHERE id_cagnotte = $1;
  $$
  LANGUAGE SQL;

/*On verifie que le viewer a un solde suffisant et que la cagnotte soit ouverte pour effetuer son don */

CREATE OR REPLACE FUNCTION check_solde_viewer()
RETURNS TRIGGER AS
$$
  DECLARE
        s int := get_solde_viewer(NEW.id_viewer);
        dispo boolean := get_cagnotte_dispo(NEW.id_cagnotte);
        com int;
        montant_versement int;
  BEGIN
    IF (s < NEW.montant_don) THEN
        RAISE EXCEPTION 'Solde insuffisant';
    END IF;
    IF (dispo = FALSE) THEN
       RAISE EXCEPTION 'Cagnotte non disponible';
    END IF;
    com := calcul_pourcentage_commission(NEW.montant_don);
    montant_versement := NEW.montant_don * (100-com)/100;
    UPDATE Cagnotte SET solde = Cagnotte.solde + montant_versement WHERE Cagnotte.id_cagnotte = NEW.id_cagnotte ; /*a changer de place*/
    UPDATE Viewer SET solde = Viewer.solde - NEW.montant_don WHERE Viewer.id_viewer = NEW.id_viewer ;
    RETURN NEW;
  END;
$$
Language plpgsql;

/*Envoie une notification aux abonnés d'un streamer lorsqu'il crée une cagnotte*/

CREATE OR REPLACE FUNCTION rappel_aux_viewer()
RETURNS TRIGGER AS
$$
  DECLARE
      abonné_streamer CURSOR FOR SELECT * FROM liste_abonnes_streamer(NEW.id_streamer);
      ligne RECORD;
  BEGIN
      FOR ligne IN abonné_streamer
      LOOP
         /*Envoie de mail ou message*/
      END LOOP;
      RETURN NEW;
  END;
$$
LANGUAGE plpgsql;

/* Ajout des differents type de commission après un don*/

CREATE OR REPLACE FUNCTION add_transaction_commission()
RETURNS TRIGGER AS
$$
  DECLARE
    com int := calcul_pourcentage_commission(NEW.montant_don);
    montant_commission int := NEW.montant_don * (com)/100;
    montant_versement int := NEW.montant_don * (100-com)/100;
    typeCagnotte boolean := type_cagnotte(NEW.id_cagnotte);
    soldeCagnotte int := get_solde_cagnotte(NEW.id_cagnotte);
    objCagnotte int := get_objectif_cagnotte(NEW.id_cagnotte);
  BEGIN
    INSERT INTO Transaction(id_don,type,montant_transaction,date_transaction)
    VALUES (NEW.id_don,'C',montant_commission,CURRENT_DATE);

    INSERT INTO Transaction(id_don,type,montant_transaction,date_transaction)
    VALUES (NEW.id_don,'D',NEW.montant_don,CURRENT_DATE);

    IF (typeCagnotte = TRUE) THEN
      INSERT INTO Transaction(id_don,type,montant_transaction,date_transaction)
      VALUES (NEW.id_don,'V',montant_versement,CURRENT_DATE);
    ELSE
      IF (soldeCagnotte >= objCagnotte) THEN
        INSERT INTO Transaction(id_don,type,montant_transaction,date_transaction)
        SELECT id_don,'V',montant_don * (100-calcul_pourcentage_commission(montant_don))/100,CURRENT_DATE
        FROM Dons
        WHERE id_cagnotte = NEW.id_cagnotte;
        UPDATE Cagnotte SET disponible = FALSE WHERE id_cagnotte = NEW.id_cagnotte;
      END IF;
    END IF;
    RETURN NEW;
  END;
$$
LANGUAGE plpgsql;

/*Gestion des cadeaux*/

CREATE OR REPLACE FUNCTION sum_dons_to_streamer(int)
RETURNS BIGINT  AS
$$
  SELECT sum(montant_don) FROM Dons , Cagnotte
  WHERE Dons.id_cagnotte = Cagnotte.id_cagnotte
  AND Cagnotte.id_streamer = $1;
$$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION calcul_seuil(bigint)
RETURNS INTEGER  AS
$$
DECLARE
  result int := 0;
BEGIN
  IF ($1 >= 100 AND $1 <500 ) THEN
    result:=1;
  ELSE
    IF ($1 >= 500 AND $1 < 1000) THEN
      result:=2;
    ELSE
      IF($1 >= 1000) THEN result:=3;
      END IF;
    END IF;
  END IF;
  RETURN result;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION random_generator(int)
RETURNS INTEGER  AS
$$
  SELECT floor(random() * $1 + 1)::int;
$$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION taille_cursor_cadeau(int,int,int)
RETURNS BIGINT AS
$$
  SELECT count(*) FROM Cadeau WHERE id_streamer = $1 AND seuil <= $2 AND quantite > 0;
$$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION add_giveaway()
RETURNS TRIGGER AS
$$
  DECLARE
    idStream int := get_idStreamer_from_cagnotte(NEW.id_cagnotte);
    somme_don bigint = sum_dons_to_streamer(idStream);
    seuil_fct int = calcul_seuil(somme_don);

    liste_cadeaux_streamer_avec_seuil CURSOR FOR
    SELECT * FROM Cadeau
    WHERE id_streamer = idStream
    AND quantite > 0
    AND seuil <= seuil_fct;

    taille_cursor int := taille_cursor_cadeau(idStream,seuil_fct,NEW.id_viewer)::int;
    random_cadeau int := random_generator(taille_cursor)::int;
    random_chance int := random_generator(10)::int;
    ligne RECORD;

  BEGIN
  IF(taille_cursor > 0) THEN
    OPEN liste_cadeaux_streamer_avec_seuil;
    FETCH ABSOLUTE random_cadeau FROM liste_cadeaux_streamer_avec_seuil INTO ligne;
    IF random_chance = 1 AND seuil_fct > 0 THEN
      INSERT INTO Giveaway(id_cadeau, id_viewer,date_giveaway) VALUES (ligne.id_cadeau,NEW.id_viewer,CURRENT_TIMESTAMP);
      UPDATE Cadeau SET quantite = quantite - 1 WHERE Cadeau.id_cadeau = ligne.id_cadeau ;
      RAISE NOTICE 'Cadeau envoyé';
    END IF;
  END IF;
  RETURN NEW;
  END;
$$
LANGUAGE plpgsql;

/* Mise a jour des solde en fonction des tranctions*/

CREATE OR REPLACE FUNCTION update_solde_plateforme_and_streamer()
RETURNS TRIGGER AS
$$
  DECLARE
    idStream int := get_idStreamer_from_don(NEW.id_don);
  BEGIN
    IF (NEW.type = 'C') THEN
      UPDATE Plateforme SET solde = solde + NEW.montant_transaction;
    ELSE
      IF (NEW.type = 'V') THEN
         UPDATE Streamer SET solde = solde + NEW.montant_transaction
         WHERE id_streamer = idStream;
      END IF;
    END IF;
    RETURN NEW;
  END;
$$
LANGUAGE plpgsql;






/* TRIGGER */

CREATE TRIGGER create_cagnotte_perso
AFTER INSERT ON Streamer
FOR EACH ROW
EXECUTE PROCEDURE cagnotte_perso();

CREATE TRIGGER notification_abonnés
AFTER INSERT ON Cagnotte
FOR EACH ROW
EXECUTE PROCEDURE rappel_aux_viewer();

CREATE TRIGGER don_valide
BEFORE INSERT ON Dons
FOR EACH ROW
EXECUTE PROCEDURE check_solde_viewer();

CREATE TRIGGER create_transaction_commission
AFTER INSERT ON Dons
FOR EACH ROW
EXECUTE PROCEDURE add_transaction_commission();

CREATE TRIGGER create_giveaway
AFTER INSERT ON Dons
FOR EACH ROW
EXECUTE PROCEDURE add_giveaway();

CREATE TRIGGER add_solde
AFTER INSERT ON Transaction
FOR EACH ROW
EXECUTE PROCEDURE update_solde_plateforme_and_streamer();






/*INSERT + Test */

INSERT INTO Streamer(nom,prenom,pseudo,mail,date_de_naissance,solde)
VALUES('Bonan','Enzo','EB','ea@ae.fr',CURRENT_DATE,0);

INSERT INTO Viewer(nom,prenom,pseudo,mail,date_de_naissance,solde)
VALUES('Chemakh','Akli','AC','ac@ae.fr',CURRENT_DATE,10000);

INSERT INTO Cadeau(id_streamer,description,quantite,seuil)
VALUES(1,'PS4 Pro',0,1);

INSERT INTO Cadeau(id_streamer,description,quantite,seuil)
VALUES(1,'Audi R8',2,3);

INSERT INTO Abonnement(id_streamer,id_viewer)
VALUES (1,1);

INSERT INTO Plateforme(societe,solde)
VALUES ('Twitch',0);

SELECT * FROM liste_cadeaux_viewer(1);

SELECT * FROM liste_abonnes_streamer(1);

SELECT id_cagnotte,solde FROM Cagnotte;

SELECT * FROM viewer;

INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES(1,1,10);
INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES(1,1,10);
INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES(1,1,10);
INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES(1,1,10);
INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES(1,1,10);
INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES(1,1,10);
INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES(1,1,10);
INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES(1,1,10);
INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES(1,1,10);
INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES(1,1,10);
INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES(1,1,10);
INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES(1,1,10);
INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES(1,1,10);
