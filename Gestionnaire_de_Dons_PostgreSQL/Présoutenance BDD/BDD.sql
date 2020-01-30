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
  quantite INTEGER NOT NULL CHECK (quantite >=0) ,
  seuil INTEGER NOT NULL CHECK (seuil >= 0)
);

CREATE TABLE Giveaway(
  id_cadeau INTEGER NOT NULL REFERENCES Cadeau(id_cadeau),
  id_viewer INTEGER NOT NULL REFERENCES Viewer(id_viewer),
  PRIMARY KEY (id_cadeau,id_viewer)
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

/*On verifie que le viewer a un solde suffisant pour effetuer son don*/

CREATE OR REPLACE FUNCTION get_solde_viewer(int)
RETURNS INTEGER AS
$$
  SELECT solde FROM Viewer ,Dons WHERE Dons.id_viewer = $1;
$$
LANGUAGE SQL;

CREATE OR REPLACE FUNCTION check_solde_viewer()
RETURNS TRIGGER AS
$$
  DECLARE
        s int := get_solde_viewer(NEW.id_viewer);
  BEGIN
        IF (s < NEW.montant_don) THEN
        RAISE EXCEPTION 'Solde insuffisant';
    END IF;
    UPDATE Cagnotte SET solde = Cagnotte.solde + NEW.montant_don WHERE Cagnotte.id_cagnotte = NEW.id_cagnotte ;
    UPDATE Viewer SET solde = Viewer.solde - NEW.montant_don WHERE Viewer.id_viewer = NEW.id_viewer ;
    RETURN NEW;
  END;
$$
LANGUAGE plpgsql;

/*Calcul de la commission en fonction du don*/





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






/*INSERT + Test */

INSERT INTO Streamer(nom,prenom,pseudo,mail,date_de_naissance,solde)
VALUES('Akli','Enzo','AE','ea@ae.fr',CURRENT_DATE,0);

INSERT INTO Viewer(nom,prenom,pseudo,mail,date_de_naissance,solde)
VALUES('Viewer','Enzo','AE','ea@ae.fr',CURRENT_DATE,100);

INSERT INTO Cadeau(id_streamer,description,quantite,seuil)
VALUES(1,'Le premier cadeau', 1, 0);

INSERT INTO Giveaway(id_cadeau, id_viewer)
VALUES (1,1);

INSERT INTO Abonnement(id_streamer,id_viewer)
VALUES (1,1);

INSERT INTO Plateforme(societe,solde)
VALUES ('Twitch',0);

INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES (1,1,75);

INSERT INTO Dons(id_cagnotte,id_viewer,montant_don)
VALUES (1,1,75);

SELECT * FROM liste_cadeaux_viewer(1);

SELECT * FROM liste_abonnes_streamer(1);

SELECT id_cagnotte,solde FROM Cagnotte;

SELECT * FROM viewer;
